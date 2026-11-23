## Physics collision layers and the masks built from them, as bitmasks.
##
## Use as `CollisionLayers.NAME`. A plain class like GameConstants, not an autoload, so it works in
## static functions, tool scripts and headless tests.
##
## How Godot uses these: a body *is on* the layers in its `collision_layer`, and *detects or collides
## with* the layers in its `collision_mask`. Ray and shape queries take a mask too. Layer N is bit
## 1 << (N - 1); the names match [layer_names] 3d_physics/layer_N in project.godot, which is what the
## editor shows. Keep both in step when a layer is added, renamed or moved.
##
## Some scenes set layers in the inspector, where constants cannot be referenced; they are listed next
## to the layer they use, so a search for the constant name finds them.
class_name CollisionLayers extends RefCounted

#region Layers
## Layer 1, "World": everything solid that stands still or runs on fixed paths. Terrain, buildings,
## tracks, roads, platforms, and rail vehicles (their VehicleCollider bodies keep Godot's default layer).
## Ground probes (station placement, road markers, road vehicles finding the road) query only this layer.
const WORLD: int = 1 << 0
## Layer 2, "RoadVehicles": the physics bodies of cars, buses and trucks (set by RoadVehicleFactory).
const ROAD_VEHICLES: int = 1 << 1

# Layer 3 is unused. Older masks (player 7, road vehicles 15) included it without anything living on it.

## Layer 4, "Player": the walking player's body (applied by PlayerAvatar). While the player drives,
## PlayerControl clears the body's layer and mask entirely and restores them on leaving the vehicle.
const PLAYER: int = 1 << 3
## Layer 20, "ClickTargets": bodies that only exist to be clicked. The mouse picker's ray (WorldPicker)
## tests every layer and finds them; nothing collides with them, since no mask includes this layer.
## Set in the inspector by: bus_stop_3d.tscn (ShelterClick), survey_marker_3d.tscn (mask 0 on both).
const CLICK_TARGETS: int = 1 << 19
#endregion

#region Masks
## What the walking player bumps into: the world and road vehicles. Not other players, not click targets.
const PLAYER_MASK: int = WORLD | ROAD_VEHICLES
## What a road vehicle collides with: the world, other road vehicles, and the walking player.
const ROAD_VEHICLE_MASK: int = WORLD | ROAD_VEHICLES | PLAYER
## What a rail station's Area3D notices: trains (on WORLD) and the walking player, for the
## trains_inside / player_entered bookkeeping. Set in the inspector by rail_stop_3d.tscn (9).
const STATION_AREA_MASK: int = WORLD | PLAYER
#endregion
