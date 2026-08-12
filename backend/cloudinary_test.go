package main

import "testing"

// The folder and file names are the part of this the seller actually sees in
// the Cloudinary console, so they are pinned.
func TestPhotoNaming(t *testing.T) {
	if got := storeFolder("Campus Snacks"); got != "Lamazon/Campus_Snacks" {
		t.Fatalf("folder: %s", got)
	}
	if got := itemPhotoName("Campus Snacks", "Cold Coffee 300ml", 2); got !=
		"Campus_Snacks_Cold_Coffee_300ml_2" {
		t.Fatalf("item photo: %s", got)
	}
	// A name that is punctuation and slashes cannot escape its folder.
	if got := storeFolder("../etc"); got != "Lamazon/etc" {
		t.Fatalf("hostile store: %s", got)
	}
	if got := itemPhotoName("../etc", "a/b", 1); got != "etc_a_b_1" {
		t.Fatalf("hostile item: %s", got)
	}
	// Category pictures live one folder per department, so Grocery's own
	// picture and everything inside it land together.
	if got := categoryFolder("Snacks & Drinks"); got !=
		"Lamazon/Categories/Snacks_Drinks" {
		t.Fatalf("category folder: %s", got)
	}
}
