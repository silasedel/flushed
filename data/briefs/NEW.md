# FLUSHED — new easy questions brief (Nov 2026)

FLUSHED is the brainrot reskin of Krillion: open-ended prompts, players try to give the RAREST valid answer.
Tiers (only these scores): 10 NPC · 30 Mid · 60 Rizz · 85 Skibidi · 100 Sigma. (The briefs in this folder still say
Plankton/Schooler/Rare/Deep Cut/One in a Krillion; same scores, same meaning. 15 is retired.)

Read these first, in data/briefs/: BRIEF.md (file format, comprehensive banks), FUN.md, ALIASES.md, RARITY2.md, REDTEAM.md.
Where they disagree with this file, THIS file wins.

## What we need
Players now play 10 prompts per game or endless runs, so the EASY pool (the only one used in normal play) runs out.
Write NEW **easy** prompts only.

- **Easy = the 90% rule**: 90%+ of American teens/young adults (late 2026) can name at least one answer within 5 seconds.
  "Name a fruit." "Name a country in Africa." "Name a battle royale game." "Name a planet." "Name a pizza topping." ✔
  "Name a moon of Uranus." "Name a Brooklyn Nine-Nine character." ✘
- Plain, short wording (ends with a period, under ~60 chars). No jargon.
- Lean INTELLECTUAL-BUT-EASY: science, nature, animals, human body, space, geography, food, everyday life, school subjects,
  words/language, math basics, history basics, brands, sports, games, music genres. Very few "Name something that…" prompts
  (max 4 in your whole file). NO prompts asking for characters from one specific show/movie/book (fandom).
- **No duplicates**: before writing a prompt, check it isn't already there: `node tools/prompts.js | grep -i <keyword>`.
  Near-duplicates (same answer set, different wording) also count as duplicates.
- **Answer banks must be comprehensive**: 50–200 answers per prompt. Include every answer a fair judge would accept,
  including creative/weird/lateral ones (e.g. for "something yellow": pee, lemon Gatorade, a school bus, Pikachu, mustard).
  Finite sets (planets, continents, US states, NFL teams…) must be COMPLETE.
  Crude/sexual answers are allowed but must start with "!" (accepted but hidden from lists), e.g. "!Pee|60".
- **Aliases** for slang, nicknames, abbreviations, brand vs. generic names, British spellings, common misspellings that are
  more than 2 letters off. No alias may collide with another answer in the same prompt.
- **Rarity for this audience** (see RARITY2.md): 1–5 answers at 10; current/popular things are LOW; old/niche/foreign are HIGH.
  Every prompt has at least one 10, 30, 60 and 85, and EXACTLY ONE 100 (the single least likely valid answer).
- American spelling in prompts and canonical answers.

## File + ids
Write ONLY your assigned file(s) in data/questions/ (named in your task), format exactly as BRIEF.md shows,
`diff:"easy"`, `pack` = one of: geography, science, general, language, fun, pop, sports, gaming, music, movies.
Use your assigned id prefix, numbered from 0001 (e.g. "xsci-0001"). Don't touch any other file.

## Check before finishing
```
node tools/validate.js data/questions/<your file>.js   # must end with OK
node tools/build.js && node tools/test.js              # must report 0 failures
node tools/try.js <id> "some answer" "another"         # spot-check matching
```
Keep a short progress log in data/briefs/progress-<prefix>.md (what's done) so you can resume if interrupted.
Final report: how many prompts you added, the file name(s), and anything you weren't sure about.
