## Industry dialog heading: the industry's own name and its type. Set industry to fill it.
class_name IndustryNameTypeBox extends MarginContainer

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		%NameLabel.text = "»%s«" % self.industry.ind_name
		%TypeLabel.text = industry.ind_type.name
