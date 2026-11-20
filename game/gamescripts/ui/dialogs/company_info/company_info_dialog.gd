## The company's cash, deliveries, income and spending. Totals update live while
## the dialog is open, since deliveries keep happening.
class_name CompanyInfoDialog extends ModalGameDialog

var _company: CompanyData


func _ready() -> void:
	%CancelButton.grab_focus()
	_company = CompanyData.current()
	%DeliveryRates.text = "%s per passenger at their destination. %s per cargo unit used by an industry." % [
		CompanyData.format_cash(CompanyData.PASSENGER_REWARD),
		CompanyData.format_cash(CompanyData.CARGO_UNIT_REWARD),
	]
	%Totals.visible = _company != null
	if _company != null:
		_company.changed.connect(_update_totals)
		_update_totals()


func _update_totals() -> void:
	%Cash.text = CompanyData.format_cash(_company.cash)
	%PassengerTotal.text = str(_company.passengers_delivered)
	%CargoTotal.text = String.num(_company.cargo_delivered, 2)
	%Income.text = CompanyData.format_cash(_company.transport_income)
	%Spending.text = CompanyData.format_cash(_company.spending)
