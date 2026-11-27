# Fill out thin answer lists (Nov 2026)

Players report "some prompts don't have many answers, some answers just don't work". Your list file names easy prompts
with fewer than 40 accepted answers. For EACH one:

1. Decide: is the full set small and finite (planets, Great Lakes, Tesla models)? Then make sure it is COMPLETE,
   and add every alias/spelling/nickname people might type. Otherwise (open-ended), expand it to 80–200 answers.
2. Brainstorm like 10 different American teens/young adults (late 2026) playing: what would they type, including
   slang, brand names, misspellings 3+ letters off, plurals, weird-but-valid lateral answers. Add all valid ones.
   Crude-but-valid answers are allowed with a leading "!" (hidden from lists).
3. Keep the rules: scores only 10/30/60/85/100, at least one each of 10/30/60/85, EXACTLY ONE 100 (the rarest),
   1–5 answers at 10. New common answers should be 10/30; new obscure ones 60/85 (don't move the existing 100 unless
   a new answer is clearly rarer — then make the old one 85).
4. Check with `node tools/try.js <id> "answer one" "answer two" ...` that what people type is accepted.

Edit the prompts IN PLACE in their existing files (only the files your list touches). Don't change prompt text unless it's
genuinely ambiguous. When done: `node tools/validate.js <your files>` must end OK, then `node tools/build.js && node tools/test.js`
with 0 failures. Report how many prompts you expanded and the before/after answer counts.
