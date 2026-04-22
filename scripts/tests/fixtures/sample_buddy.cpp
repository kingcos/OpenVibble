#include "../buddy.h"
namespace sample {
static void doIdle(uint32_t t) {
  static const char* const REST[5] = { "A", "B", "C", "D", "E" };
  static const char* const LOOK[5] = { "a", "b", "c", "d", "e" };
  const char* const* P[2] = { REST, LOOK };
  static const uint8_t SEQ[] = { 0, 1, 0 };
  uint8_t beat = (t / 5) % sizeof(SEQ);
  buddyPrintSprite(P[SEQ[beat]], 5, 0, 0xC2A6);
}
}
