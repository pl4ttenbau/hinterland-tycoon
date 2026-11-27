## One rail gauge, loaded from game/jsondata/rail_types.json.
class_name RailType extends Resource

## Matches RailTrackData.infr_type_key and vehicle usable_infr subtypes, e.g. "750_MM".
var key: String
## Bedded track scene; its root is a RailTrack3D.
var scene: PackedScene
## Distance between the inner faces of the rails, used for construction quotes.
var gauge_mm: int
## Distance from the track curve up to the top of the rail, where wheels run.
var rail_head_height_metres: float
