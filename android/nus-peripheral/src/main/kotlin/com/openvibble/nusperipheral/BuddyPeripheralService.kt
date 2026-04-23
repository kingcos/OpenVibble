// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@file:Suppress("MissingPermission")

package com.openvibble.nusperipheral

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import com.openvibble.protocol.NDJSONLineFramer
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Android BLE peripheral that exposes the Nordic UART Service so Claude
 * Desktop's central can connect. Mirrors iOS BuddyPeripheralService — same
 * advertise-or-name-only modes, same 180-byte notify chunking, same NDJSON
 * line framing on RX.
 *
 * The class is thread-safe in the sense that all public methods can be
 * invoked from any thread; internal mutation of GATT state happens on the
 * main looper via the BluetoothGattServerCallback.
 */
@SuppressLint("MissingPermission")
class BuddyPeripheralService(private val context: Context) {

    private val _connectionState = MutableStateFlow<NusConnectionState>(NusConnectionState.Stopped)
    val connectionState: StateFlow<NusConnectionState> = _connectionState.asStateFlow()

    private val _powerState = MutableStateFlow(BluetoothPowerState.UNKNOWN)
    val powerState: StateFlow<BluetoothPowerState> = _powerState.asStateFlow()

    private val _advertisingNote = MutableStateFlow("未广播")
    val advertisingNote: StateFlow<String> = _advertisingNote.asStateFlow()

    private val _bluetoothStateNote = MutableStateFlow("蓝牙状态未知")
    val bluetoothStateNote: StateFlow<String> = _bluetoothStateNote.asStateFlow()

    private val _diagnostics = MutableStateFlow<List<String>>(emptyList())
    val diagnostics: StateFlow<List<String>> = _diagnostics.asStateFlow()

    /** Callback fired once per fully-framed NDJSON line received on the RX characteristic. */
    var onLineReceived: ((String) -> Unit)? = null

    private val adapter: BluetoothAdapter? by lazy {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        manager?.adapter
    }
    private val bluetoothManager: BluetoothManager? by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    }
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    private val subscribedCentrals: MutableMap<String, BluetoothDevice> =
        Collections.synchronizedMap(LinkedHashMap())

    private val framer = NDJSONLineFramer()
    private val pending = NotifyChunker()

    private var isStarted: Boolean = false
    private var advertisedName: String = "Claude-Android"
    private var includeServiceUuidInAdvertisement: Boolean = true

    fun setAdvertisementMode(includeServiceUuid: Boolean) {
        includeServiceUuidInAdvertisement = includeServiceUuid
        log("ADV mode includeServiceUUID=$includeServiceUuid")
    }

    fun start(displayName: String) {
        advertisedName = displayName
        isStarted = true
        log("START requested name=$displayName")

        if (!hasRequiredRuntimePermissions()) {
            _bluetoothStateNote.value = "蓝牙权限被拒绝"
            _powerState.value = BluetoothPowerState.UNKNOWN
            log("START blocked: missing runtime permissions")
            return
        }

        val adapter = adapter
        if (adapter == null) {
            _bluetoothStateNote.value = "设备不支持 BLE 外设"
            _powerState.value = BluetoothPowerState.UNSUPPORTED
            log("START blocked: no adapter")
            return
        }

        syncPowerStateFromAdapter(adapter)
        if (!adapter.isEnabled) {
            log("START blocked state=${adapter.state}")
            return
        }
        if (adapter.bluetoothLeAdvertiser == null) {
            _bluetoothStateNote.value = "设备不支持 BLE 外设"
            _powerState.value = BluetoothPowerState.UNSUPPORTED
            log("START blocked: no LE advertiser")
            return
        }

        setupAndAdvertiseIfNeeded()
    }

    fun stop() {
        log("STOP requested")
        isStarted = false

        pending.clear()
        subscribedCentrals.clear()

        advertiser?.let {
            runCatching { it.stopAdvertising(advertiseCallback) }
        }
        advertiser = null

        gattServer?.let {
            runCatching { it.close() }
        }
        gattServer = null

        txCharacteristic = null
        rxCharacteristic = null
        _connectionState.value = NusConnectionState.Stopped
        _advertisingNote.value = "未广播"
        log("STOP completed")
    }

    /**
     * Sends a single NDJSON line (newline appended if missing) to every
     * subscribed central. Returns `false` when nothing is connected — the
     * caller can use that as a back-pressure signal, same as iOS.
     */
    fun sendLine(line: String): Boolean {
        if (subscribedCentrals.isEmpty()) return false
        val payload = (if (line.endsWith("\n")) line else "$line\n").toByteArray(Charsets.UTF_8)
        pending.enqueue(payload)
        drainPending()
        return true
    }

    /** Read current Bluetooth power state — useful for Settings UI on demand. */
    fun refreshPowerState() {
        val adapter = adapter ?: run {
            _powerState.value = BluetoothPowerState.UNSUPPORTED
            _bluetoothStateNote.value = "设备不支持 BLE 外设"
            return
        }
        syncPowerStateFromAdapter(adapter)
    }

    private fun setupAndAdvertiseIfNeeded() {
        val manager = bluetoothManager ?: return
        if (gattServer == null) {
            gattServer = manager.openGattServer(context, gattServerCallback)
            if (gattServer == null) {
                _advertisingNote.value = "GATT 服务器启动失败"
                log("GATT open failed")
                return
            }
            val service = buildService()
            val added = runCatching { gattServer?.addService(service) }.getOrNull() ?: false
            if (added != true) {
                _advertisingNote.value = "GATT 服务添加失败"
                log("GATT addService returned false")
                return
            }
            // Advertising kicks off from onServiceAdded callback.
            return
        }
        startAdvertising()
    }

    private fun buildService(): BluetoothGattService {
        val service = BluetoothGattService(NusUuids.service, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        val tx = BluetoothGattCharacteristic(
            NusUuids.tx,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        val cccd = BluetoothGattDescriptor(
            NusUuids.cccd,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE,
        )
        tx.addDescriptor(cccd)

        val rx = BluetoothGattCharacteristic(
            NusUuids.rx,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )

        service.addCharacteristic(tx)
        service.addCharacteristic(rx)

        txCharacteristic = tx
        rxCharacteristic = rx
        return service
    }

    private fun startAdvertising() {
        val adapter = adapter ?: return
        val led = adapter.bluetoothLeAdvertiser ?: run {
            _advertisingNote.value = "未广播"
            log("ADV no advertiser")
            return
        }
        advertiser = led

        _advertisingNote.value = "请求开始广播"

        // iOS uses CBAdvertisementDataLocalNameKey. Android has two slots —
        // the primary advertisement frame and the scan response. Including
        // the service UUID + name in the same 31-byte frame can overflow, so
        // we put the name in the scan response to match iOS discoverability.
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        val dataBuilder = AdvertiseData.Builder()
        if (includeServiceUuidInAdvertisement) {
            dataBuilder.addServiceUuid(ParcelUuid(NusUuids.service))
        }

        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()

        if (adapter.name != advertisedName) {
            runCatching { adapter.name = advertisedName }
        }

        runCatching {
            led.startAdvertising(settings, dataBuilder.build(), scanResponse, advertiseCallback)
            log(
                if (includeServiceUuidInAdvertisement)
                    "ADV start mode=name+service name=$advertisedName service=${NusUuids.SERVICE_STRING}"
                else
                    "ADV start mode=name-only name=$advertisedName"
            )
        }.onFailure {
            _advertisingNote.value = "广播失败: ${it.message ?: ""}"
            log("ADV failed error=${it.message}")
        }
    }

    private fun drainPending() {
        val server = gattServer ?: return
        val tx = txCharacteristic ?: return
        while (!pending.isEmpty()) {
            val chunk = pending.peek() ?: break
            val centrals = synchronized(subscribedCentrals) { subscribedCentrals.values.toList() }
            if (centrals.isEmpty()) return
            var success = true
            for (device in centrals) {
                val ok = notifyCentral(server, tx, device, chunk)
                if (!ok) success = false
            }
            if (success) {
                pending.consume()
            } else {
                return
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun notifyCentral(
        server: BluetoothGattServer,
        characteristic: BluetoothGattCharacteristic,
        device: BluetoothDevice,
        payload: ByteArray,
    ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val status = runCatching {
            server.notifyCharacteristicChanged(device, characteristic, false, payload)
        }.getOrDefault(BluetoothGatt.GATT_FAILURE)
        status == BluetoothGatt.GATT_SUCCESS
    } else {
        characteristic.value = payload
        runCatching {
            server.notifyCharacteristicChanged(device, characteristic, false)
        }.getOrDefault(false)
    }

    private fun hasRequiredRuntimePermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val connect = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
            val advertise = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADVERTISE)
            return connect == PackageManager.PERMISSION_GRANTED &&
                advertise == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    private fun syncPowerStateFromAdapter(adapter: BluetoothAdapter) {
        val state = when (adapter.state) {
            BluetoothAdapter.STATE_ON -> BluetoothPowerState.ON
            BluetoothAdapter.STATE_OFF -> BluetoothPowerState.OFF
            BluetoothAdapter.STATE_TURNING_ON -> BluetoothPowerState.TURNING_ON
            BluetoothAdapter.STATE_TURNING_OFF -> BluetoothPowerState.TURNING_OFF
            else -> BluetoothPowerState.UNKNOWN
        }
        _powerState.value = state
        _bluetoothStateNote.value = when (state) {
            BluetoothPowerState.ON -> "蓝牙已开启"
            BluetoothPowerState.OFF -> "蓝牙已关闭"
            BluetoothPowerState.TURNING_ON -> "蓝牙开启中"
            BluetoothPowerState.TURNING_OFF -> "蓝牙关闭中"
            BluetoothPowerState.UNKNOWN -> "蓝牙状态未知"
            BluetoothPowerState.UNSUPPORTED -> "设备不支持 BLE 外设"
        }
    }

    private val gattServerCallback: BluetoothGattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            val address = device.address
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                subscribedCentrals.remove(address)
                val count = subscribedCentrals.size
                _connectionState.value = if (count > 0) NusConnectionState.Connected(count)
                else if (isStarted) NusConnectionState.Advertising
                else NusConnectionState.Stopped
                _advertisingNote.value = if (count > 0) "已连接" else if (isStarted) "广播中" else "未广播"
                log("DISCONNECT device=$address count=$count")
            } else if (newState == BluetoothProfile.STATE_CONNECTED) {
                log("LINK established device=$address (awaiting CCCD subscribe)")
            }
        }

        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                log("SERVICE add success uuid=${service.uuid}")
                if (isStarted) startAdvertising()
            } else {
                _advertisingNote.value = "服务注册失败: $status"
                log("SERVICE add failed status=$status")
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            val server = gattServer
            if (descriptor.uuid == NusUuids.cccd) {
                val enabling = value != null && value.isNotEmpty() &&
                    (value[0].toInt() and 0x03) != 0
                if (enabling) {
                    subscribedCentrals[device.address] = device
                    val count = subscribedCentrals.size
                    _connectionState.value = NusConnectionState.Connected(count)
                    _advertisingNote.value = "已连接"
                    log("SUBSCRIBE device=${device.address} count=$count")
                    if (responseNeeded) {
                        server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
                    }
                    drainPending()
                } else {
                    subscribedCentrals.remove(device.address)
                    val count = subscribedCentrals.size
                    _connectionState.value = if (count > 0) NusConnectionState.Connected(count)
                    else if (isStarted) NusConnectionState.Advertising
                    else NusConnectionState.Stopped
                    log("UNSUBSCRIBE device=${device.address} count=$count")
                    if (responseNeeded) {
                        server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
                    }
                }
            } else {
                if (responseNeeded) {
                    server?.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, 0, null)
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            val server = gattServer
            if (characteristic.uuid != NusUuids.rx) {
                log("WRITE unsupported characteristic=${characteristic.uuid}")
                if (responseNeeded) {
                    server?.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, offset, null)
                }
                return
            }
            if (value != null) {
                log("WRITE rx bytes=${value.size}")
                val lines = try {
                    framer.ingest(value)
                } catch (t: Throwable) {
                    framer.reset()
                    emptyList()
                }
                for (line in lines) {
                    onLineReceived?.invoke(line)
                }
            }
            if (responseNeeded) {
                server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
            }
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                drainPending()
            }
        }
    }

    private val advertiseCallback: AdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            _advertisingNote.value = "广播中"
            _connectionState.value = if (subscribedCentrals.isEmpty())
                NusConnectionState.Advertising
            else
                NusConnectionState.Connected(subscribedCentrals.size)
            log("ADV started ok")
        }

        override fun onStartFailure(errorCode: Int) {
            _advertisingNote.value = "广播失败: $errorCode"
            _connectionState.value = NusConnectionState.Stopped
            log("ADV failed error=$errorCode")
        }
    }

    private fun log(line: String) {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val stamp = formatter.format(Date())
        val existing = _diagnostics.value
        val next = buildList(capacity = minOf(existing.size + 1, 300)) {
            add("[$stamp] $line")
            for (entry in existing) {
                if (size >= 300) break
                add(entry)
            }
        }
        _diagnostics.value = next
    }
}
