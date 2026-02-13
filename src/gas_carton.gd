extends ItemBody

const ITEM_TYPE = 'GAS_CARTON'
const MAX_FUEL = 100

func _ready():
	# override item name description
	item_name = 'Gas Carton'
	item_description = 'A carton of gas that can be used to refuel the RV.'
