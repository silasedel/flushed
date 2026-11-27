# Red-team sweep: every easy prompt must accept everything a fair judge would (Nov 2026)

The player is frustrated: valid answers keep getting rejected (latest: "side flip" for "a word that goes after 'side'").
Your job is coverage, nothing fancy: for EVERY easy prompt in your files (diff "easy", or listed easy in data/difficulty.js),
make sure the answer list has everything people would actually type that's correct.

For each prompt:
1. Play it as 15 different American teens/young adults (late 2026): the obvious answers, the slangy ones, brand names,
   abbreviations, plurals/singulars, full phrases ("side flip" vs "flip"), common misspellings 3+ letters off,
   specific-vs-general forms (e.g. "golden retriever" for a dog prompt that says "animal"), and weird-but-valid lateral answers.
2. Test them in batches: `node tools/try.js <id> "answer one" "answer two" ...` (shows ok/MISS).
3. Add every valid MISS: `node tools/addmany.js <id> "Name|score|alias|alias" "Name2|score" ...`
   (it skips anything already accepted). Scores: obvious = 10/30, fair-but-rarer = 60, obscure = 85. Never add a 100
   (there must stay exactly one). Crude-but-valid answers start with "!". Wrong answers must stay rejected.
4. If an existing alias should be its own answer or an answer is clearly mis-scored for this audience, fix it in the file.
Don't change prompt wording, don't drop prompts, don't touch files outside your list.

Aim for real coverage: open-ended prompts should end with 80–200+ answers; finite sets must be complete with all aliases.
At the end: `node tools/validate.js <your files>` must end OK, and `node tools/try.js` on 3–5 tricky inputs per prompt passes.
Other agents edit other files and some writers are adding new files, so ignore build/test output about files that aren't yours.
Report: prompts swept, answers added, aliases added, anything you weren't sure about.

## NEW RULE (overrides "don't change prompt wording"): quantify anything you can't list completely
If a prompt's real-world answer set is too big to list completely (cities/towns in a place, lakes, rivers, restaurants,
bands, brands, YouTubers, apps, schools...), REWORD the prompt to add a clear, checkable threshold, then make the list
COMPLETE for that threshold:
- places: "Name a city in Nebraska with 25,000+ people." / "Name a city in Sweden (50,000+ people)."
- chains/brands: "Name a restaurant chain with 500+ US locations."  rivers: "Name a river over 1,000 miles long."
Keep any smaller real answers you already have as accepted bonus answers (usually 85). Pick a threshold low enough that
the prompt stays easy and high enough that you can list every qualifying answer from solid knowledge.
Finite sets (capitals, states, planets, teams) don't need this — just make them complete.
