extends ItemBody

const ITEM_TYPE = 'GAS_CARTON'
const MAX_FUEL = 100
const POUR_RATE = 0.1
var current_fuel: float = float(MAX_FUEL)

func _ready():
	# override item name description
	item_name = 'Gas Carton'
	item_description = 'A carton of gas that can be used to refuel the RV.'
