# Changelog

All notable AnimeW changes and bug fixes are recorded here, newest first.

## 2026-11-07

### Poster Card and Search
- Reduced the size and padding of poster information chips for a less oversized look.
- Fixed poster artwork stretching when a title occupies only one line by reserving a consistent title area.
- Moved status and popularity information into the metadata line below the title instead of overlaying the poster.
- Added status, views, format, and episode-count metadata to search result cards.
- Removed the extra `EP` caption above titles in the New Episodes row.


### Poster Card
- Kept the score badge background black and changed the star and score text colors according to the rating.
- Removed the views badge background and used an eye icon.
- Formatted popularity without spaces, using `rb` and `jt` (for example, `155rb` and `1.2jt`).
- Added the `Segera` status for titles that have not started airing, with a yellow-orange background.
- Rounded status badge corners further and increased status/score tag sizing.
- Moved views beside episode information in the AniList Continue and New Episodes rows.
- Removed the extra episode-count badge from New Episodes.
- Moved Trending rank closer below the status badge and softened its font weight.
- Tightened the title-to-metadata spacing and kept the app's default font.
- Slightly increased the size of poster information text.

### Tracker rows
- Fixed tracker score conversion for poster badges: tracker scores use a 0–10 decimal scale, while poster badges use an integer 0–100 scale.
- Fixed upcoming/status access to read metadata from the nested media item rather than the tracker list entry.
- Kept tracker popularity labels compact and without spaces.

### Build fixes
- Corrected Dart type errors in tracker poster score arguments.
- Corrected the invalid `isUpcoming` getter access in tracker list rows.
