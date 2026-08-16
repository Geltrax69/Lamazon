package main

// shippedPolicies is the text a fresh database starts with. It is a draft, not
// legal advice: it says what Lamazon actually does today, and it is written to
// be replaced from the admin panel.
//
// What this cannot know — the registered company name, its address, a phone
// number, a grievance officer — is left as a bracketed blank rather than
// invented. A made-up registration on a live policy page is worse than an
// obvious gap, and the blanks are what tell an admin where to start.
//
// "## " at the start of a line is a heading. That is the whole format.
func shippedPolicies() []Policy {
	return []Policy{
		{Slug: "terms", Title: "Terms and Conditions", Body: termsText},
		{Slug: "privacy", Title: "Privacy Policy", Body: privacyText},
		{Slug: "shipping", Title: "Shipping Policy", Body: shippingText},
		{Slug: "refunds", Title: "Cancellation and Refunds", Body: refundsText},
		{Slug: "contact", Title: "Contact Us", Body: contactText},
	}
}

const termsText = `Last updated: [Date]

## Who we are
Lamazon is a campus marketplace. Shops on campus list what they sell, students
and staff order it, and a delivery partner brings it across. We run the
platform; we do not make or own the goods.

Company/App Name: [Company Name]
Registered address: [Registered Business Address]

## Your account
You sign in with your email address, and we send a code to it to prove the
address is yours. You may also set a password. Keep your account to yourself —
anything ordered from it is treated as ordered by you. Tell us straight away if
you think somebody else has got into it.

## Orders
Placing an order is an offer to buy. It becomes a sale when the shop accepts
it, which is also the moment your four-digit delivery code is issued. A shop
can turn an order down — usually because they have run out — and you are told
the reason.

## Prices
Shops set their own prices and their own MRP. Where a discount is shown, it is
the difference between the two as the shop entered them. Prices include taxes
unless a shop says otherwise. We may cancel an order that was listed at an
incorrect price, and anything already paid is refunded in full.

## Selling on Lamazon
Anyone on campus can open a store, and an admin reviews it before shoppers can
see it. You are responsible for what you list: that it is yours to sell, that
it is described honestly, and that it is safe to eat, use or wear. We can take
a listing or a store down if it is not.

## What we are responsible for
The quality of what a shop sells is the shop's. We will help you sort out a
problem, but the contract for the goods is between you and the shop. Nothing in
these terms affects any mandatory consumer rights available to you under
applicable Indian law.

## Changes
We may update these terms. The latest version is always the one in the app, and
if a change matters to how you use Lamazon we will say so before it takes
effect.`

const privacyText = `Last updated: [Date]

## What we collect
Your email address, and the name and mobile number you give us so an order can
reach you. Your delivery addresses. What you have ordered. If you open a store:
its name, location, photo and what you list.

## Why we collect it
To deliver your orders and to let the shop and the rider do their part. Your
name, number and address go to the shop packing your order and the rider
carrying it, because neither can hand it over without them. Nothing else about
you goes with it.

## The four digits at the door
Every delivery has a code. It is shown only to you and checked only by the
rider at hand-over — they are never told what it is, which is what makes typing
it proof that the two of you met.

## Emails and notifications
We email you sign-in codes and order updates. If you turn on notifications we
also send those to your browser or phone; you can turn them off again in
Settings, and email carries on either way.

## Photos
Store and product photos you upload are stored with our image host and served
publicly as part of your listing. Do not upload anything you would not want a
shopper to see.

## How long we keep it
Your account and order history stay while your account exists. Sign-in codes
are deleted the moment they are used or expire. Ask us to delete your account
and we will remove your personal details; records a shop or the law requires
them to keep may remain with them.

## Who else sees it
The shop you ordered from, the rider delivering it, and the services we use to
send email, store photos and deliver notifications. We do not sell your data to
anybody.

[Replace with the list of service providers once these are settled.]

## Contact
Questions about your data, or a request to delete it: [support@email.com]`

const shippingText = `Last updated: [Date]

We currently deliver orders to serviceable locations within India.

## Delivery time
Estimated delivery times are displayed during checkout or communicated after
the order is placed. Delivery times may vary because of location, product
availability, weather, holidays, logistics issues, or other circumstances
beyond our reasonable control.

## Shipping charges
Applicable delivery or shipping charges are displayed before you complete your
order.

## Delivery issues
If your order is delayed, damaged, incomplete, or delivered to the wrong
address, please contact us as soon as reasonably possible with your order
details.

Customers are responsible for providing a correct and complete delivery address
and contact information.

## Receiving your order
The rider calls the number on the order. Have your four-digit delivery code
ready — the order is only closed when it is entered, which is how we know it
reached you and not somebody else.`

const refundsText = `Last updated: [Date]

## Cancellation
You may request cancellation of your order before it is dispatched, subject to
the applicable status of the order.

Once an order has been dispatched or delivered, cancellation may not be
possible. In such cases, you may be eligible for a return or refund according
to our applicable return and refund conditions.

We may cancel an order in situations such as product unavailability, incorrect
pricing, suspected fraudulent activity, or operational issues.

## Refunds
If an order qualifies for a refund, the refund will generally be processed to
the original payment method or through another appropriate method. Refund
processing time may depend on the payment provider or bank.

Refunds may be applicable in circumstances including:

- Order cancellation where payment has already been made.
- Product being unavailable after payment.
- Incorrect, damaged, or defective product, where applicable.
- Failure to deliver an order due to reasons attributable to us.
- Other circumstances where a refund is required under applicable law.

Certain products may have specific return or refund conditions due to their
nature. These conditions are communicated on the relevant product page or at
checkout.

Nothing in this policy affects any mandatory consumer rights available under
applicable Indian law.

## Requesting a refund
Contact us with your order ID and the relevant details. Quote the order number
shown on the order and the customer id on your account page; with those two we
can find anything.`

const contactText = `Last updated: [Date]

If you have questions, complaints, refund requests, or other concerns, please
contact us.

## Contact details
Company/App Name: [Company Name]
Email: [support@email.com]
Phone: [Phone Number]
Address: [Registered Business Address]
Support hours: [Days and Time]

## How we handle it
We aim to acknowledge customer complaints and requests within a reasonable time
and resolve them as quickly as reasonably possible.

For consumer complaints, you may also have rights and remedies available under
applicable Indian consumer protection laws.

## Grievance Officer
Name: [Name]
Email: [grievance@email.com]
Phone: [Phone Number]

## Changes
We may update this policy from time to time. The latest version will be
available on our app or website.`
