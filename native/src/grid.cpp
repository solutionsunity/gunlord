#include "grid.h"

#include "gd.h"

#include <algorithm>
#include <cmath>

namespace gunlord {

void Grid::build(const Lane &lane) {
	const int n = lane.size();
	std::fill(start.begin(), start.end(), 0);
	cell.resize(n);
	items.resize(n);
	for (int i = 0; i < n; i++) {
		const int cx = gd::clamp(int(std::floor((lane.x[i] - X0) / CELL)), 0, COLS - 1);
		const int cz = gd::clamp(int(std::floor((lane.z[i] - Z0) / CELL)), 0, ROWS - 1);
		const int c = cz * COLS + cx;
		cell[i] = c;
		start[c + 1] += 1;
	}
	for (int c = 0; c < COLS * ROWS; c++) {
		start[c + 1] += start[c];
	}
	cursor = start;
	for (int i = 0; i < n; i++) {
		items[cursor[cell[i]]++] = i;
	}
}

int Grid::first_hit(const Lane &lane, double px, double pz, int skip_serial, bool hits_traps) const {
	const int cx = int(std::floor((px - X0) / CELL));
	const int cz = int(std::floor((pz - Z0) / CELL));
	for (int gz = cz - 1; gz < cz + 2; gz++) {
		if (gz < 0 || gz >= ROWS || start[gz * COLS] == start[gz * COLS + COLS]) {
			continue;   // off the grid, or a row with nothing in it
		}
		for (int gx = cx - 1; gx < cx + 2; gx++) {
			if (gx < 0 || gx >= COLS) {
				continue;
			}
			const int c = gz * COLS + gx;
			for (int k = start[c]; k < start[c + 1]; k++) {
				const int i = items[k];
				if (!lane.alive[i] || lane.serial[i] == skip_serial) {
					continue;
				}
				const ObjectSpec &d = lane.def(i);
				if (d.is_trap() && !hits_traps) {
					continue;
				}
				const double r = d.radius + HIT_MARGIN;
				if (gd::pow2(lane.x[i] - px) + gd::pow2(lane.z[i] - pz) <= r * r) {
					return i;
				}
			}
		}
	}
	return -1;
}

} // namespace gunlord
