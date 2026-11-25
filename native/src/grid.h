#pragma once

#include "lane.h"

#include <vector>

namespace gunlord {

// Uniform grid over the lane, rebuilt every tick with a counting sort.
// A projectile only tests objects in its own cell and the eight around it,
// so CELL must be at least the largest object radius plus the hit margin.
class Grid {
public:
	static constexpr double CELL = 2.0;
	static constexpr double X0 = -8.0;
	static constexpr double Z0 = -80.0;
	static constexpr int COLS = 8;
	static constexpr int ROWS = 46;
	static constexpr double HIT_MARGIN = 0.25;

	void build(const Lane &lane);
	int first_hit(const Lane &lane, double px, double pz, int skip_serial, bool hits_traps) const;

private:
	std::vector<int> start = std::vector<int>(COLS * ROWS + 1);   // cell c holds items[start[c] .. start[c + 1]]
	std::vector<int> items;
	std::vector<int> cell;
	std::vector<int> cursor;
};

} // namespace gunlord
