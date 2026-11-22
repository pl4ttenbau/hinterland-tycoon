## Project-wide tuning values that several systems must agree on, the constant counterpart to Enums.
##
## Use as `GameConstants.NAME`. Unlike Enums this is not an autoload: constants on a named class are
## available everywhere without a node in the tree, including static functions, tool scripts and
## headless tests.
##
## Only world-level values belong here: ones that tie systems together, so changing them in one place
## must change them everywhere. Domain constants (brake defaults, resistance coefficients, notch-up
## times, road corner speeds, ...) stay next to the code that explains them; a central list of bare
## numbers would lose that context.
class_name GameConstants extends RefCounted

#region Physical units
## Standard gravity in m/s². Railway and road engineering use 9.81 throughout; more digits would be
## false precision. Weight force, adhesion, gradient and resistance formulas all rest on it.
## Godot's physics engine (road vehicles' wheels, the walking player) does not read this: it uses the
## project setting physics/3d/default_gravity, which is unset and so at Godot's default of 9.8. The
## 0.2 % difference is irrelevant for gameplay; set that setting to 9.81 if they should ever match exactly.
const GRAVITY: float = 9.81
## Multiply m/s by this for km/h, divide km/h by it for m/s. Catalogs, signs and the speedometer speak
## km/h; every simulation runs in m/s.
const KMH_PER_MPS: float = 3.6
#endregion

#region Math
## A quarter turn in radians, for rotating models across or along a track or road. Exact PI / 2:
## earlier local copies used 1.57 or 1.57079, which left buffers, junctions and platforms a few
## hundredths of a degree askew.
const NINETY_DEG_IN_RAD: float = PI / 2.0
#endregion

#region World scale
## Map metres per real metre for moving vehicles.
##
## The maps are drawn 1:1 (4 m per heightmap pixel), but towns sit far closer together than in
## reality. At real speeds trains would hop between them in moments, so vehicles cover only this share
## of the real distance on the map. Everything physical stays real: catalog speeds, forces, prices, and
## the km/h on the speedometer. Only the distance travelled on the map is scaled.
##
## Effects at 0.66:
## - a train showing 30 km/h crosses the map at about 20 km/h (5.5 m/s);
## - accelerating and braking take as long as in reality, but over two thirds of the map distance;
## - signal and buffer distances, measured on the map, stand for 1 / 0.66 ≈ 1.5 times as much real
##   distance when trains plan their stops.
##
## Conversions: real → map with `* MAP_DISTANCE_SCALE`, map → real with `/ MAP_DISTANCE_SCALE`.
## Used by TrainMovement. Road vehicles drive with wheel physics and are not scaled yet; when they are,
## they should use this same value so trains and cars stay comparable.
const MAP_DISTANCE_SCALE: float = 0.66
#endregion

#region Player
## Walking speed of the player on foot, in map metres per second.
##
## Deliberately a little quicker than a real person for the game's sake, but slow enough that a moving
## train clearly pulls away. Compared in the trains' scaled terms (divide by MAP_DISTANCE_SCALE), 3 m/s
## on the map is like jogging at about 16 km/h; the old 5 m/s was a 27 km/h sprint that could keep up
## with a Saxon IV K at full speed. A train just starting off can still be caught.
##
## PlayerAvatar applies it to the walking body on startup, overriding the FPS addon's default
## (BasicFpsPlayer.SPEED, 5 m/s). Speed in the air and jump height keep the addon's values.
const PLAYER_WALK_SPEED: float = 3.0
#endregion
