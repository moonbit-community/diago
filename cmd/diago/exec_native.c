#include <stdint.h>
#include <stdlib.h>

#include "moonbit.h"

MOONBIT_FFI_EXPORT
int32_t diago_system(moonbit_bytes_t command) {
  return (int32_t)system((const char *)command);
}
