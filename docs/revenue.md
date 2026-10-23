# Revenue research (2026-10-23)

Kyle's idea: construction/DIY ads (tools, easy-to-use products), with a paid
"remove ads". Researched by a Claude agent on 2026-10-23; sources inline.

## Is there a construction/DIY in-app ad network?
No that takes small indie apps, as far as the research found.
- Home Depot's retail media (Orange Apron Media) buys offsite through big
  platforms — Reddit, Pinterest, The Trade Desk, Meta, Google
  ([Marketing Dive](https://www.marketingdive.com/news/home-depot-helps-advertisers-reach-diy-audiences-on-reddit-and-pinterest/818253/),
  [AdExchanger](https://www.adexchanger.com/commerce/the-home-depots-path-to-becoming-a-global-advertising-player)).
  No small-publisher program.
- Lowe's One Roof offsite runs through Yahoo's DSP
  ([2022 release](https://www.businesswire.com/news/home/20221013005274/en/), may be dated).
- Tool brands (DeWalt, Milwaukee, GRK, Simpson): no brand affiliate programs
  found; only resellers, e.g. International Tool ~8%
  ([FlexOffers](https://www.flexoffers.com/affiliate-programs/international-tool-affiliate-program/)),
  Toolbarn 5–10%. Sponsorship would be a direct pitch.
- Carbon Ads is invite-only and developer/design-focused
  ([FAQ](https://carbonads.net/faq)); EthicalAds wants 50k+ monthly
  pageviews, developer audiences, ~$2.50 CPM
  ([guide](https://www.ethicalads.io/publisher-guide/)).

## What can actually run in this app
- **No mainstream ad SDK for native Mac.** AdMob documents iOS only
  ([docs](https://developers.google.com/admob/ios)); AppLovin has no official
  Mac support. On iPhone, US banners pay about $0.45 eCPM
  ([Appodeal Q4 2024](https://appodeal.com/the-mobile-ecpm-report-updated-q4-2024-view)).
- **Affiliate links, matched to what's typed** (`16d` → nails, `1/2" NPT` →
  fittings). Amazon Associates US: 3% home improvement, 1.75% tools
  ([rates](https://affiliate-program.amazon.com/help/node/topic/GWSMACYG6EJMNW74)).
  Its app policy requires a free app in an approved store with links usable
  without paying, plus separate approval
  ([policy](https://affiliate-program.amazon.com/help/node/topic/GQZMCDD9PB7CXV7N)) —
  unclear whether the Mac App Store counts. Home Depot (Impact) ~1% and Lowe's
  ~2% (0% lumber), 24-hour cookies, per third-party sources.

## Apple rules
- Ads allowed in the main app; users must be able to see why an ad was
  targeted and report it (guideline 2.5.18,
  [guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- "Remove ads" should be an in-app purchase (3.1.1); the guidelines don't name
  ad removal specifically, but it's a common pattern.
- **Mac App Store apps must update only through the store (2.4.5)** — an App
  Store build must leave out the GitHub self-updater and "Try a Build…".
- ATT prompt only if data is linked with other companies' for
  targeting/measurement ([Apple](https://developer.apple.com/app-store/user-privacy-and-data-use/));
  on-device keyword matching with plain links likely doesn't need it.
- Open source (MIT): anyone can build it without ads, so "remove ads" sells
  convenience and support.

## Recommended paths (ranked)
1. **Contextual "where to buy" links**, matched on the device, no SDK, no
   tracking. First step: apply to Amazon Associates under its app policy and
   ask whether a Mac App Store app qualifies; then a keyword → product table.
2. **One hand-sold sponsor** ("presented by" a tool or fastener brand), a
   non-tracking card. First step: a one-page media kit once there are usage
   numbers.
3. **Supporter purchase** that hides the links/sponsor card, instead of
   banner ads.
