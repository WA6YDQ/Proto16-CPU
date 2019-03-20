/* bootrom code called at cpu startup */
/* (C) k theis 2/2019 */

#include <stdint.h>

uint16_t *mem;

void bootrom(void) {

	mem[0] = 0x2000;	// halt (invoke the hardware monitor) */
	return;
}
