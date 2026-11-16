echo "Hand Hermes Desktop the Mid’hat theme as a skin"

# Only the app Mid’hat installed under Install > AI follows the theme by itself.
# A Hermes the user set up some other way keeps whatever skin they chose.
midhat-pkg-present hermes-desktop || exit 0

# The same hand-over a fresh install does. A Hermes that is not ready or refuses
# the write is reported and done with there; only Mid’hat's own failures return.
midhat-theme-set-hermes --activate
