---
name: twitter-reader
description: Read Twitter/X posts, threads, and articles using the free fxtwitter API. Use when the user shares an x.com or twitter.com URL, asks to read a tweet, fetch tweet content, summarize a Twitter thread, or needs engagement metrics from a post. No API key required.
---

# Twitter Reader (fxtwitter)

Read tweets, threads, and long-form X Articles via `api.fxtwitter.com`. Free, no auth.

## Quick Start

Given any `x.com` or `twitter.com` URL, fetch via:

```
https://api.fxtwitter.com/{user}/status/{tweet_id}
```

Use `webfetch` or `curl` on that URL. Returns JSON with full tweet content.

## URL Patterns

All of these work — extract the username and status ID:

```
https://x.com/username/status/1234567890
https://twitter.com/username/status/1234567890
https://x.com/username/status/1234567890?s=20
```

Rewrite to: `https://api.fxtwitter.com/username/status/1234567890`

## Response Structure

The JSON response contains:

```json
{
  "code": 200,
  "tweet": {
    "url": "https://x.com/...",
    "id": "...",
    "text": "Tweet body text",
    "author": {
      "screen_name": "handle",
      "name": "Display Name",
      "description": "Bio",
      "followers": 1234,
      "avatar_url": "..."
    },
    "replies": 10,
    "retweets": 50,
    "likes": 200,
    "bookmarks": 30,
    "views": 5000,
    "created_at": "Mon Jun 08 17:38:44 +0000 2026",
    "media": { "photos": [...], "videos": [...] },
    "article": {
      "title": "Article title",
      "content": { "blocks": [...] }
    }
  }
}
```

## Key Fields

| Field | Description |
|-------|-------------|
| `tweet.text` | Tweet body (short posts) |
| `tweet.article` | Long-form X Article (title + blocks) |
| `tweet.article.content.blocks[].text` | Article paragraphs |
| `tweet.author` | Author profile info |
| `tweet.replies/retweets/likes/bookmarks/views` | Engagement |
| `tweet.media` | Attached photos/videos |
| `tweet.replying_to` | Username being replied to (null if top-level) |
| `tweet.created_at` | Timestamp |

## Workflows

### Read a single tweet

1. Extract username and tweet ID from URL
2. Fetch `https://api.fxtwitter.com/{user}/status/{id}`
3. Parse `tweet.text` for short posts, or `tweet.article.content.blocks` for articles
4. Present with engagement stats and author info

### Read a thread

fxtwitter returns individual tweets. For threads:

1. Fetch the first tweet
2. Check if `tweet.replying_to` is the same author (indicates thread continuation)
3. Follow `tweet.replying_to_status` if available
4. Or ask user for each tweet URL in the thread

### Extract article content

For long-form X Articles (`tweet.article` is present):

1. `tweet.article.title` — the headline
2. `tweet.article.content.blocks[]` — array of content blocks
3. Each block has `.text` (paragraph content) and `.type` (`unstyled`, `unordered-list-item`, etc.)
4. `.inlineStyleRanges` has bold/italic/strikethrough formatting
5. `.entityRanges` + `.entityMap` contain links

### Get user info from a tweet

The `tweet.author` object includes: `name`, `screen_name`, `description` (bio), `followers`, `following`, `likes`, `joined`, `verification`, `avatar_url`, `banner_url`.

## Additional Endpoints

```
# User profile (without needing a tweet)
https://api.fxtwitter.com/{username}

# Direct media (images/video)
https://api.fxtwitter.com/{user}/status/{id}  → tweet.media
```

## Limitations

- No search (use Exa/websearch for finding tweets)
- No thread auto-expansion (fetch each tweet individually)
- No user timeline listing (only individual tweets by ID)
- Rate limits exist but are generous for normal use
