class_name IndustryNameTypeBox extends MarginContainer

@export var industry: IndustryData:
	get(): return industry
	set(value):
		industry = value
		%NameLabel.text = "»%s«" % self.industry.ind_name
		%TypeLabel.text = industry.ind_type.name
