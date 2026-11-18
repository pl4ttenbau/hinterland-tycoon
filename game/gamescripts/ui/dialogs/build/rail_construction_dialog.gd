extends MenuShellDialog

signal build_requested()

const Quote = preload("res://game/gamescripts/resources/infr/rail_construction_quote.gd")

var quote: Quote

func _ready() -> void:
	dialog_key = "RailConstruction"
	title_text = "Build rail section"
	super._ready()
	%OkButton.text = "Back to plan"
	%LengthValue.text = "%.1f m" % quote.length_metres
	%GaugeValue.text = "%d mm" % quote.gauge_mm
	%PriceValue.text = CompanyData.format_cash(quote.price)
	%BuildButton.pressed.connect(build_requested.emit)
	var company := CompanyData.current()
	if company != null:
		show_error(company.spending_error(quote.price))

func show_error(message: String) -> void:
	%Status.text = message
	%Status.visible = not message.is_empty()
