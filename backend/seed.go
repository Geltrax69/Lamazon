package main

// Catalog seed, mirroring what the Flutter app ships so both sides agree.
// ponytail: a literal, not a fixtures loader — it is read-only sample data.
func seedProducts() []Product {
	return []Product{
		{
			ID: "p1", Name: "Brown Denim Jacket", Category: "Men's outfit",
			Tab: "All", Price: 1799, Store: "Velora Store",
			ImageURL:    "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400",
			Description: "Washed denim jacket with a boxy fit and button front.",
			Offers:      []Offer{{Store: "Urban Threads", Price: 1699}},
		},
		{
			ID: "p2", Name: "Grey Casual Shoe", Category: "Men Footwear",
			Tab: "All", Price: 999, Store: "Velora Store",
			ImageURL:    "https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?w=400",
			Description: "Canvas low-tops with a cushioned insole.",
		},
		{
			ID: "p3", Name: "Wireless Headphones", Category: "Audio",
			Tab: "Electronics", Price: 2499, Store: "GadgetHub",
			ImageURL:    "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400",
			Description: "Over-ear bluetooth headphones, 30-hour battery.",
			Offers:      []Offer{{Store: "TechnoWorld", Price: 2299}},
		},
		{
			ID: "p4", Name: "Smart Watch", Category: "Wearables",
			Tab: "Electronics", Price: 4499, Store: "TechnoWorld",
			ImageURL:    "https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=400",
			Description: "Fitness tracking, heart rate, 7-day battery.",
		},
		{
			ID: "p5", Name: "Fresh Milk 1L", Category: "Dairy",
			Tab: "Grocery", Price: 68, Store: "Nature Fresh",
			ImageURL:    "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400",
			Description: "Full-cream milk, pasteurised.",
			Offers: []Offer{
				{Store: "FreshMart", Price: 66},
				{Store: "Daily Basket", Price: 70},
			},
		},
		{
			ID: "p6", Name: "Veg Biryani", Category: "Biryani",
			Tab: "Food", Price: 249, Store: "Spice Kitchen",
			ImageURL:    "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400",
			Description: "Basmati rice layered with spiced vegetables.",
		},
		{
			ID: "p7", Name: "Premium Gift Hamper", Category: "Hampers",
			Tab: "Gifts", Price: 1299, Store: "Wrap & Give",
			ImageURL:    "https://images.unsplash.com/photo-1513201099705-a9746e1e201f?w=400",
			Description: "Chocolates, candles and a handwritten card.",
		},
		{
			ID: "p8", Name: "Matte Lipstick", Category: "Makeup",
			Tab: "Beauty", Price: 599, Store: "GlowUp",
			ImageURL:    "https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400",
			Description: "Long-wear matte finish, eight shades.",
		},
	}
}

func seedShops() []Shop {
	return []Shop{
		{Name: "Velora Store", Tagline: "Trendy fashion, up to 40% off", Tab: "All",
			ImageURL: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400"},
		{Name: "GadgetHub", Tagline: "Latest electronics & audio", Tab: "Electronics",
			ImageURL: "https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400"},
		{Name: "FreshMart", Tagline: "Farm-fresh groceries daily", Tab: "Grocery",
			ImageURL: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=400"},
		{Name: "Spice Kitchen", Tagline: "Hot meals in 30 min", Tab: "Food",
			ImageURL: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400"},
		{Name: "Wrap & Give", Tagline: "Gifts for every occasion", Tab: "Gifts",
			ImageURL: "https://images.unsplash.com/photo-1513201099705-a9746e1e201f?w=400"},
		{Name: "GlowUp", Tagline: "Skincare & makeup essentials", Tab: "Beauty",
			ImageURL: "https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400"},
	}
}

// ServiceableCities is where the porters currently deliver. One campus for
// now, same as the app.
var ServiceableCities = []string{"Lovely Professional University"}

var cityAliases = map[string]string{
	"lpu":                            "Lovely Professional University",
	"lovely professional university": "Lovely Professional University",
	"lpu phagwara":                   "Lovely Professional University",
	"lpu, phagwara":                  "Lovely Professional University",
}

// SellCategories are the categories a seller can list under.
var SellCategories = []string{
	"Electronics", "Clothes", "Stationary", "Gifts", "Food", "Grocery",
}
