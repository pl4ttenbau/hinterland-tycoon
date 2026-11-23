## A place on a track or road: one of its nodes, plus a signed distance along the curve from that node.
##
## Why not just a node index, or just a distance from the line's start?
## - A node index alone only allows places exactly on an authored point.
## - A distance from the start ("curve offset") allows any place, but every edit before it (a wider
##   curve, a moved point) silently slides the place along the line.
## Node + offset keeps the place tied to the geometry next to it: edits far away do not move it.
##
## Invariant (decided 2026-11-20): the node is the one nearest to the place along the curve. An anchor
## made with at_curve_offset() or normalized() always satisfies it; one read from JSON may not, until it
## is normalized. Offsets therefore stay within half a segment of their node.
##
## Pure data: it does not hold its line. Callers pass the line in, so stops, depots and route points can
## all share this without new reference cycles between lines and the things placed on them.
##
## JSON: {"nodeIndex": 4, "nodeOffset": 12.5}. "nodeOffset" is optional and 0 when missing, so records
## that only have "nodeIndex" (all maps up to 2026-11-23) read unchanged as places exactly on a node.
class_name LineAnchor extends Resource

## Offsets are stored in centimetres, like positions in the map JSON.
const OFFSET_DECIMALS_FACTOR: float = 100.0

## Index of the node the place is measured from.
@export var node_index: int = 0
## Metres along the curve from the node: positive toward the next node (higher index), negative
## toward the previous one.
@export var offset: float = 0.0

func _init(_node_index: int = 0, _offset: float = 0.0) -> void:
	self.node_index = _node_index
	self.offset = _offset

#region Creation
## The anchor for a distance along the line's curve, attached to the nearest node. On a tie (exactly
## halfway between two nodes) the earlier node wins, so the result does not depend on float noise order.
static func at_curve_offset(line: AbstractInfrLine, distance: float) -> LineAnchor:
	distance = clampf(distance, 0.0, line.length())
	var nearest: int = 0
	var nearest_offset: float = 0.0
	var nearest_gap: float = INF
	for index: int in range(line.node_count()):
		var node_distance: float = line.node_offset(index)
		var gap: float = absf(node_distance - distance)
		if gap < nearest_gap:
			nearest = index
			nearest_offset = node_distance
			nearest_gap = gap
	return LineAnchor.new(nearest, distance - nearest_offset)

## The same place, re-attached to its nearest node. Use after reading JSON, or after the line changed.
func normalized(line: AbstractInfrLine) -> LineAnchor:
	return LineAnchor.at_curve_offset(line, self.curve_offset(line))
#endregion

#region Resolving on a line
## Whether the node exists on `line`. The offset itself is always usable: it is clamped to the line.
func is_valid_on(line: AbstractInfrLine) -> bool:
	return line != null and line.has_node_index(self.node_index)

## Distance along the line's curve, clamped to the line, or -1 when the node does not exist.
func curve_offset(line: AbstractInfrLine) -> float:
	var base: float = line.node_offset(self.node_index)
	if base < 0.0:
		return -1.0
	return clampf(base + self.offset, 0.0, line.length())

## World position of the place, or the line start when the node does not exist (check is_valid_on).
## A place exactly on its node returns the node's authored position: sampling the baked curve there would
## be off by a few millimetres, and existing stops would shift slightly on every load.
func position_on(line: AbstractInfrLine) -> Vector3:
	if self.offset == 0.0 and self.is_valid_on(line):
		return line.get_node_at(self.node_index).position
	return line.position_at(maxf(0.0, self.curve_offset(line)))
#endregion

#region JSON
## Reads "nodeIndex" and the optional "nodeOffset" from a stop/depot record; null when either is invalid.
## Does not normalize: the line may not be loaded yet.
static func from_dict(data: Dictionary) -> LineAnchor:
	var index: Variant = data.get("nodeIndex")
	if not (index is int or index is float) or not is_finite(float(index)) or index < 0 or index != int(index):
		return null
	var node_offset: Variant = data.get("nodeOffset", 0.0)
	if not (node_offset is int or node_offset is float) or not is_finite(float(node_offset)):
		return null
	return LineAnchor.new(int(index), float(node_offset))

## Writes the anchor into `data`. A zero offset (after rounding to centimetres) is left out, so places
## on a node keep the short form every existing record uses.
func write_to(data: Dictionary) -> void:
	data["nodeIndex"] = self.node_index
	var rounded: float = roundf(self.offset * OFFSET_DECIMALS_FACTOR) / OFFSET_DECIMALS_FACTOR
	if rounded == 0.0:
		data.erase("nodeOffset")
	else:
		data["nodeOffset"] = rounded

## Two anchors name the same place on the same line, to the centimetre the JSON stores.
func same_place(other: LineAnchor) -> bool:
	return other != null and other.node_index == self.node_index \
		and roundf(other.offset * OFFSET_DECIMALS_FACTOR) == roundf(self.offset * OFFSET_DECIMALS_FACTOR)

func _to_string() -> String:
	return "node %d %+.2f m" % [self.node_index, self.offset]
#endregion
