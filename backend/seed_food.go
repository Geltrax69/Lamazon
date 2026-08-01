package main

// Two real campus restaurants, seeded as ordinary seller stores rather than
// catalogue rows. That is the point: they go in through the same door a
// student opens their own store through, so if these show up in the Food tab,
// so will anyone else's.
//
// Prices are in rupees, from the printed menus. Where a menu lists two prices
// for one dish (half and full), the half portion is the listed item and the
// full portion is a second line, because the app has one price per item.

type menuStore struct {
	Owner      string
	Name       string
	Location   string
	Categories []string
	Items      []menuItem
}

type menuItem struct {
	Title    string
	Section  string // the menu heading it sits under
	Price    float64
	Category string // the app tab it lands in
}

// foodStores is seeded once, the first time the database is empty.
func foodStores() []menuStore {
	return []menuStore{
		{
			Owner:      "purebites@lamazon.app",
			Name:       "Pure Bites",
			Location:   "Bite into happiness",
			Categories: []string{"Food"},
			Items:      pureBitesMenu(),
		},
		{
			Owner:      "khanakhajana@lamazon.app",
			Name:       "Khana Khajana",
			Location:   "Chaat, chinese and tandoor",
			Categories: []string{"Food"},
			Items:      khanaKhajanaMenu(),
		},
	}
}

func food(section string, items ...menuItem) []menuItem {
	for i := range items {
		items[i].Section = section
		items[i].Category = "Food"
	}
	return items
}

func dish(title string, price float64) menuItem {
	return menuItem{Title: title, Price: price}
}

func pureBitesMenu() []menuItem {
	var m []menuItem
	m = append(m, food("Thalis",
		dish("PB Special Thali", 129),
		dish("Normal Thali", 99),
		dish("Lacha Parantha Thali", 110),
		dish("Roti Sabzi Thali", 89),
	)...)
	m = append(m, food("Combos (Rice / Roti)",
		dish("Chana Combo", 79),
		dish("Kadi Combo", 89),
		dish("Paneer Combo", 99),
		dish("Rajma Combo", 79),
		dish("Mix Veg Combo", 79),
		dish("Soya Champ Combo", 89),
		dish("Dal Makhani Combo", 99),
	)...)
	m = append(m, food("Breakfast",
		dish("Chana Bhatura", 99),
		dish("Puri Bhaji / Chana Puri", 79),
		dish("Aloo Parantha", 39),
		dish("Gobhi Parantha", 39),
		dish("Mix Parantha", 55),
		dish("Paneer Parantha", 60),
		dish("Bread Pakora", 79),
	)...)
	m = append(m, food("Main Course",
		dish("Dal Makhani (Half)", 99),
		dish("Dal Makhani (Full)", 135),
		dish("Mix Veg", 99),
		dish("White Chana", 99),
		dish("Rajma Masala", 110),
		dish("Dal Tadka", 99),
		dish("Jeera Aloo", 99),
		dish("Aloo Gobhi", 99),
		dish("Kadhai Paneer (Half)", 129),
		dish("Kadhai Paneer (Full)", 179),
		dish("Shahi Paneer (Half)", 129),
		dish("Shahi Paneer (Full)", 179),
		dish("Mutter Paneer (Half)", 129),
		dish("Mutter Paneer (Full)", 169),
		dish("Paneer Bhurji", 99),
		dish("Paneer Lababdar (Half)", 129),
		dish("Paneer Lababdar (Full)", 189),
		dish("Masala Mushroom", 159),
		dish("Mushroom Kadhai", 169),
		dish("Tawa Champ Gravy", 149),
		dish("Palak Paneer", 149),
	)...)
	m = append(m, food("Biryani",
		dish("Veg Biryani", 119),
		dish("Hyderabadi Biryani", 139),
		dish("Paneer Biryani", 139),
		dish("Soya Champ Biryani", 129),
	)...)
	m = append(m, food("Burgers",
		dish("Aloo Tikki Burger", 69),
		dish("Aloo Cheese Burger", 89),
		dish("Double Cheese Burger", 119),
		dish("Paneer Tikki Burger", 129),
		dish("PB's Special Burger", 129),
	)...)
	m = append(m, food("Sandwiches",
		dish("Cheese Corn Sandwich", 99),
		dish("Spinach Corn Sandwich", 119),
		dish("Paneer Makhani Sandwich", 129),
		dish("Mac and Cheese Sandwich", 119),
		dish("Cheese Loaded Sandwich", 129),
		dish("Desi Aloo Sandwich", 99),
		dish("PB's Special Sandwich", 149),
	)...)
	m = append(m, food("Wraps",
		dish("Aloo Tikki Wrap", 99),
		dish("Paneer Wrap", 119),
		dish("Mushroom Corn Wrap", 119),
	)...)
	m = append(m, food("French Fries",
		dish("Salted Fries", 79),
		dish("Peri Peri Fries", 99),
		dish("Cheese Loaded Fries", 119),
		dish("Aloo Tikki Loaded Fries", 129),
		dish("Paneer Loaded Fries", 139),
	)...)
	m = append(m, food("Pasta",
		dish("White Sauce Pasta", 129),
		dish("Red Sauce Pasta", 139),
		dish("Mix Sauce Pasta", 139),
	)...)
	m = append(m, food("Mojitos",
		dish("Black Currant Mojito", 89),
		dish("Strawberry Mojito", 89),
		dish("Blueberry Mojito", 89),
		dish("Iced Tea (Lemon / Peach)", 89),
		dish("Mint Mojito", 89),
		dish("Watermelon Mojito", 89),
		dish("Passionfruit Mojito", 89),
		dish("Green Apple Mojito", 99),
	)...)
	m = append(m, food("Frappes",
		dish("Hazelnut Frappe", 129),
		dish("Mocha Frappe", 139),
		dish("Caramel Frappe", 139),
		dish("Vanilla Frappe", 139),
		dish("Oreo Frappe", 129),
		dish("Biscoff Frappe", 139),
	)...)
	m = append(m, food("Shakes",
		dish("Mango Shake", 79),
		dish("Vanilla Shake", 89),
		dish("Butterscotch Shake", 89),
		dish("Vanilla Banana Shake", 89),
		dish("Oreo Shake", 99),
		dish("KitKat Shake", 99),
		dish("Bourbon Shake", 99),
		dish("Nutella Shake", 139),
		dish("Biscoff Shake", 149),
		dish("Blackcurrant Shake", 99),
		dish("Strawberry Shake", 99),
		dish("Sweet Lassi", 89),
	)...)
	m = append(m, food("Hot Beverages",
		dish("Hot Coffee", 49),
		dish("Kullad Tea", 39),
		dish("Regular Tea", 29),
		dish("Hot Chocolate", 119),
		dish("Herbal Tea", 99),
		dish("Green Tea", 69),
	)...)
	m = append(m, food("Extras",
		dish("Roti", 8),
		dish("Butter Roti", 10),
		dish("Parantha", 20),
		dish("Lacha Parantha", 25),
		dish("Steam Rice", 69),
		dish("Green Salad", 69),
		dish("Mix Vegetable Raita", 89),
		dish("Extra Cheese", 19),
		dish("Extra Aloo Tikki", 39),
	)...)
	return m
}

func khanaKhajanaMenu() []menuItem {
	var m []menuItem
	m = append(m, food("Mehar's Special",
		dish("Bun Samosa", 50),
		dish("Samosa Chaat (Single)", 50),
		dish("Samosa Chaat (Double)", 80),
		dish("Special Cholle Tikki Chaat", 100),
		dish("Royal Creamy Bhalla", 120),
		dish("Patty Kulcha (Maida)", 200),
		dish("Patty Kulcha (Atta)", 230),
	)...)
	m = append(m, food("Gol Gappe & Chaat",
		dish("Pani Wale Gol Gappe (5 pcs)", 50),
		dish("Stuffed Gol Gappe (5 pcs)", 60),
		dish("Tikki Chaat", 80),
		dish("Bhalla Papdi Chaat", 120),
		dish("Shahi Papdi Chaat", 130),
	)...)
	m = append(m, food("All Day Breakfast",
		dish("Jumbo Puri Chole", 100),
		dish("Chole Bhature", 120),
		dish("Amritsari Naan (Maida)", 120),
		dish("Amritsari Naan (Atta)", 140),
		dish("Onion Naan (Maida)", 130),
		dish("Onion Naan (Atta)", 140),
		dish("Mix Naan (Maida)", 150),
		dish("Mix Naan (Atta)", 170),
		dish("Gobi Naan (Maida)", 150),
		dish("Gobi Naan (Atta)", 170),
		dish("Paneer Naan (Maida)", 220),
		dish("Paneer Naan (Atta)", 250),
		dish("Cheese Kulcha (Maida)", 250),
		dish("Cheese Kulcha (Atta)", 270),
	)...)
	m = append(m, food("Chinese",
		dish("Spring Roll", 80),
		dish("Veg Noodles", 180),
		dish("Honey Chilli Potatoes", 180),
		dish("Hakka Noodles", 190),
		dish("Chilli Garlic Noodles", 180),
		dish("Singapuri Noodles", 200),
		dish("Gravy Manchurian", 200),
		dish("Paneer Noodles", 220),
		dish("Dry Manchurian", 230),
		dish("Cheese Corn Rolls", 240),
		dish("Mushroom Duplex", 300),
		dish("Cheese Chilli", 300),
		dish("Crispy Corn", 150),
		dish("Paneer Fingers", 300),
		dish("Mushroom Chilli", 290),
		dish("Veg Fried Rice", 100),
		dish("Paneer Fried Rice", 150),
	)...)
	m = append(m, food("Dosa",
		dish("Sambar Vada", 100),
		dish("Plain Paper Dosa", 120),
		dish("Onion Dosa", 120),
		dish("Masala Dosa", 150),
		dish("Butter Masala Dosa", 160),
		dish("Paneer Dosa", 180),
		dish("Butter Paneer Dosa", 200),
	)...)
	m = append(m, food("Sandwiches & Wraps",
		dish("Brown Bread Sandwich", 40),
		dish("White Bread Sandwich", 30),
		dish("Grilled Veg Sandwich", 120),
		dish("Grilled Paneer Sandwich", 150),
		dish("Veg Wrap", 100),
		dish("Paneer Wrap", 130),
	)...)
	m = append(m, food("Momos & Soup",
		dish("Steamed Veg Momos (10 pcs)", 120),
		dish("Fried Veg Momos (10 pcs)", 140),
		dish("Hot & Sour Soup", 130),
		dish("Veg Manchow Soup", 130),
		dish("Lemon Coriander Soup", 130),
		dish("Sweet Corn Soup", 130),
	)...)
	m = append(m, food("Rice Bowls (weekends)",
		dish("Special Palak & Chana Bowl", 70),
		dish("Rajma & Chawal", 80),
		dish("Curry & Chawal", 90),
	)...)
	m = append(m, food("Pizza",
		dish("Simple Cheese Pizza (Small)", 190),
		dish("Simple Cheese Pizza (Medium)", 240),
		dish("Simple Cheese Pizza (Large)", 350),
		dish("Corn & Capsicum Pizza (Small)", 200),
		dish("Corn & Capsicum Pizza (Medium)", 280),
		dish("Corn & Capsicum Pizza (Large)", 400),
		dish("Veg Pizza (Small)", 220),
		dish("Veg Pizza (Medium)", 300),
		dish("Veg Pizza (Large)", 440),
		dish("Veg Supreme Pizza (Small)", 250),
		dish("Veg Supreme Pizza (Medium)", 350),
		dish("Veg Supreme Pizza (Large)", 480),
		dish("Double Cheese Pizza (Small)", 250),
		dish("Double Cheese Pizza (Medium)", 350),
		dish("Double Cheese Pizza (Large)", 480),
		dish("Spicy Paneer Pizza (Small)", 250),
		dish("Spicy Paneer Pizza (Medium)", 360),
		dish("Spicy Paneer Pizza (Large)", 500),
	)...)
	m = append(m, food("Burgers",
		dish("Aloo Tikki Burger", 60),
		dish("Aloo Tikki Burger Combo", 160),
		dish("Mix Veg Burger", 70),
		dish("Mix Veg Burger Combo", 170),
		dish("Jumbo Burger", 120),
		dish("Jumbo Burger Combo", 200),
		dish("Paneer Supreme Burger", 140),
		dish("Paneer Supreme Burger Combo", 220),
		dish("Extra Cheese Slice", 30),
	)...)
	m = append(m, food("Fries & Thali",
		dish("Regular Fries", 80),
		dish("Peri Peri Fries", 100),
		dish("Special Veg Thali", 250),
	)...)
	m = append(m, food("Shakes",
		dish("Vanilla Shake", 140),
		dish("Chocolate Shake", 140),
		dish("Strawberry Shake", 140),
		dish("Cold Coffee", 120),
		dish("Oreo Shake", 150),
		dish("KitKat Shake", 150),
		dish("Milk Badam Can", 150),
		dish("Butterscotch Shake", 170),
		dish("Pineapple Shake", 140),
		dish("Mango Shake", 140),
	)...)
	m = append(m, food("Mocktails & Lassi",
		dish("Fresh Lime Soda", 60),
		dish("Garden Mint Mojito", 150),
		dish("Ocean Blue Lagoon", 150),
		dish("Go Green Apple", 150),
		dish("Salted Lassi", 70),
		dish("Sweet Lassi", 80),
		dish("Mango Lassi", 100),
		dish("Rose Lassi", 120),
	)...)
	m = append(m, food("Hot Beverages",
		dish("Adrak Elaichi Tea", 60),
		dish("Gur Elaichi Tea", 70),
		dish("Masala Tea", 60),
		dish("Hot Coffee", 70),
		dish("French Vanilla Coffee", 120),
	)...)
	return m
}
