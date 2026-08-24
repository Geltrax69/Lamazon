package main

import (
	"reflect"
	"testing"
)

// Reordering is the one place the client hands back a list of URLs, so it is
// the one place a listing could be pointed at somebody else's picture.
func TestOrderPhotos(t *testing.T) {
	current := []string{"a.jpg", "b.jpg", "c.jpg"}

	t.Run("reorders", func(t *testing.T) {
		got, err := orderPhotos(current, []string{"c.jpg", "a.jpg", "b.jpg"})
		if err != nil {
			t.Fatal(err)
		}
		want := []string{"c.jpg", "a.jpg", "b.jpg"}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("got %v, want %v", got, want)
		}
	})

	t.Run("a shorter list is how a photo is removed", func(t *testing.T) {
		got, err := orderPhotos(current, []string{"b.jpg"})
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got, []string{"b.jpg"}) {
			t.Errorf("got %v", got)
		}
	})

	t.Run("a URL the item does not have is refused", func(t *testing.T) {
		_, err := orderPhotos(current, []string{"a.jpg", "https://evil/x.png"})
		if err == nil {
			t.Fatal("a foreign URL was accepted onto the listing")
		}
	})

	t.Run("duplicates collapse", func(t *testing.T) {
		got, err := orderPhotos(current, []string{"a.jpg", "a.jpg", "b.jpg"})
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got, []string{"a.jpg", "b.jpg"}) {
			t.Errorf("got %v", got)
		}
	})

	t.Run("emptying is allowed", func(t *testing.T) {
		got, err := orderPhotos(current, nil)
		if err != nil || len(got) != 0 {
			t.Errorf("got %v, %v", got, err)
		}
	})

	t.Run("whitespace is trimmed, not treated as a new URL", func(t *testing.T) {
		got, err := orderPhotos(current, []string{" a.jpg "})
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got, []string{"a.jpg"}) {
			t.Errorf("got %v", got)
		}
	})
}
