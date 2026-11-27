## Review step of rail construction: shows the length, gauge and price of the
## drawn track before anything is built. Build track (OK) runs the rail
## builder's on_submit handler, which builds, charges and closes, or returns why
## it cannot. Cancel ("Back to plan") returns to the plan to keep drawing.
class_name RailConstructionDialog extends ConfirmDialog

const Quote = preload("res://game/gamescripts/resources/infr/rail_construction_quote.gd")

var quote: Quote

func _ready() -> void:
	# 1. Content: the quote under review.
	_show_quote()
	# 2. Validation: warn up front when the company cannot pay.
	var company := CompanyData.current()
	if company != null:
		show_status(company.spending_error(quote.price), StatusTone.ERROR)
	%CancelButton.grab_focus()

func _show_quote() -> void:
	%LengthValue.text = "%.1f m" % quote.length_metres
	%GaugeValue.text = "%d mm" % quote.gauge_mm
	%PriceValue.text = CompanyData.format_cash(quote.price)
