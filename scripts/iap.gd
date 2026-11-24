extends Node





signal purchased(product_id: String)

const PRODUCTS: = {
	"remove_ads": {"title": "Remove Ads", "price": "$2.99"}, 
	"coins_small": {"title": "1,000 Coins", "price": "$0.99", "coins": 1000}, 
}

func available() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("GodotGooglePlayBilling")

func purchase(id: String) -> void :
	if available():
		_purchase_real(id)
	elif OS.is_debug_build():
		_grant(id)
	else:
		push_warning("IAP not available on this platform")

func _purchase_real(_id: String) -> void :
	pass

func _grant(id: String) -> void :
	if id == "remove_ads": Game.data["remove_ads"] = true
	elif PRODUCTS.has(id) and PRODUCTS[id].has("coins"): Game.data["coins"] = int(Game.data["coins"]) + int(PRODUCTS[id]["coins"])
	Game.save_game()
	purchased.emit(id)
