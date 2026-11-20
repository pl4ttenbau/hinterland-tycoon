## Preview image, price and speed for one road vehicle type.
class_name RoadVehicleTypePreview extends VBoxContainer

@onready var image: TextureRect = %Image
@onready var placeholder: Label = %Placeholder
@onready var details: Label = %Details

## A model-folder preview.png is optional; adding it requires no dialog changes.
func show_type(type: RoadVehicleTypeData) -> void:
	var path: String = type.get_preview_img_path()
	image.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	placeholder.visible = image.texture == null
	var speed: String = "%.0f km/h" % float(type.max_speed_kmh) if type.max_speed_kmh != null else "Unspecified"
	var price: Variant = type.get_purchase_price()
	var price_text: String = "DM %d" % price if price != null else "Price unknown"
	details.text = "Purchase price: %s\nMaximum speed: %s" % [price_text, speed]
	details.tooltip_text = "Purchase price in game money." if price != null \
		else "Speed, motor power and transport capacity are required to calculate a price."
