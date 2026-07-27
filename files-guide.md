# מדריך קבצים — מה נמצא בכל קובץ

רשימה מלאה של הקבצים בפרויקט, לפי סדר הבנייה המומלץ. אין כאן קוד מלא בכוונה — הכתיבה היא שלך.

---

## קבצי שורש

### `package.json`
הגדרות הפרויקט. שלושה דברים חייבים להיות שם:
- `"type": "module"` — בלי זה `import` לא יעבוד
- סקריפטים: `start` (מריץ את `src/server.js`), `dev` (עם `--watch`), `test` (מריץ `node --test`)
- תלויות: `express`, `mongodb`, `@supabase/supabase-js`, `dotenv`

### `.env`
הערכים האמיתיים: `PORT`, `MONGO_URI`, `MONGO_DB_NAME`, `SUPABASE_URL`, `SUPABASE_KEY`. **לא נכנס לגיט.**

### `.env.example`
אותם מפתחות בדיוק, עם ערכים ריקים. כן נכנס לגיט, כדי שמי שמשכפל את הפרויקט ידע מה הוא צריך למלא.

### `.gitignore`
לפחות: `node_modules`, `.env`

### `.dockerignore`
לפחות: `node_modules`, `.env`, `.git`. זה מקטין את האימג' ומונע דליפת סודות לתוכו.

### `seed.sql`
**זה הקובץ שהיה לא ברור.** הוא לא חלק מהאפליקציה ואף שורת קוד לא קוראת לו. הוא קובץ SQL שאתה מריץ פעם אחת ידנית ב-SQL Editor של Supabase, והוא עושה שני דברים: יוצר את שלוש הטבלאות (`CREATE TABLE`), ומכניס להן נתוני התחלה (`INSERT`). בלעדיו יש לך מסד נתונים ריק ואין על מה לפתח. הכנתי אותו לך במלואו בקובץ הנפרד.

### `Dockerfile`
מתכון לבניית האימג' של השרת. הסדר הנכון: בסיס `node:20-alpine` → `WORKDIR` → העתקת `package*.json` → `npm ci` → העתקת שאר הקוד → `EXPOSE` → `CMD`. ההעתקה של ה-package לפני הקוד היא מכוונת, כדי ששכבת ההתקנה תישמר בקאש ולא תרוץ מחדש בכל שינוי קוד.

### `docker-compose.yml`
מתזמר שני שירותים: `api` (נבנה מה-Dockerfile) ו-`mongo` (אימג' רשמי עם volume בשם). מגדיר `env_file`, מיפוי פורטים, ו-`depends_on`.

---

## `src/` — נקודות הכניסה

### `src/server.js`
הקובץ הקצר בפרויקט, כעשר שורות. מייבא את `app`, מייבא את הקונפיג, ומרים `app.listen(port)`. זה הכל. הפרדה זו קיימת כדי שהטסטים יוכלו לייבא את `app` בלי להרים שרת אמיתי.

### `src/app.js`
מרכיב את אפליקציית אקספרס: יוצר `express()`, מחבר `express.json()`, מחבר את הראוטר, ואז את `notFound` ואת `errorHandler` — **בסדר הזה, ובסוף**. מייצא את `app` בלי להאזין.

---

## `src/config/`

### `config/env.js`
קורא `dotenv/config`, מוודא שכל משתני הסביבה הנדרשים קיימים, ומתפוצץ מיד עם הודעה ברורה אם משהו חסר. מייצא אובייקט קונפיג מסודר. זה המקום היחיד בפרויקט שנוגע ב-`process.env`.

---

## `src/db/` — חיבורים

### `db/mongo.js`
סינגלטון לחיבור מונגו. שומר את ה-Promise של `connect()` ולא את התוצאה, כדי שקריאות מקבילות לא ייצרו שני קליינטים. מייצא `getDb()` ו-`disconnect()`. **חייב `await` בכל מקום שקורא לו** — זה הבאג שראינו בקוד הקודם.

### `db/supabase.js`
שורות ספורות: יוצר client עם `createClient(url, key)` ומייצא אותו. אין כאן לוגיקה.

---

## `src/repositories/` — הדיבור עם המסדים

הכלל: רפוזיטורי יודע לקרוא ולכתוב, ולא יודע שום חוק עסקי. הוא לא זורק שגיאות 403 ולא בודק הרשאות.

### `repositories/investigators.repository.js`
`findByCodename`, `findById`, `create`. מול Supabase.

### `repositories/creatures.repository.js`
`find(filter)` עם תמיכה בסינון לפי classification ו-threat, ו-`findById`. מול Supabase.

### `repositories/cases.repository.js`
`findById` (רצוי עם join שמביא גם את היצור והחוקר), `findOpenByPair`, `create`, `updateStatus`, ו-`findIdsByCreature` — שהאחרון נחוץ לאנדפוינט הדוסייה. מול Supabase.

### `repositories/reports.repository.js`
היחיד שנוגע במונגו. `findByCaseId`, `findByCaseIds` (מקבל מערך, בשביל הדוסייה), `countByCaseId`, ו-`create`. אחראי גם להמיר `_id` ל-`id` לפני שהוא מחזיר.

---

## `src/services/` — החוקים העסקיים

כל שירות הוא פונקציית מפעל שמקבלת את הרפוזיטוריים שהוא צריך כפרמטרים, ומחזירה אובייקט של פונקציות. זה מה שיאפשר לך להזריק מוקים בטסטים. אין כאן `req`, אין `res`, ואין `res.status`. שגיאות נזרקות עם `err.status`.

### `services/investigators.service.js`
`createInvestigator` — ולידציה של שדות חובה, טווח clearance, ובדיקת codename כפול.

### `services/cases.service.js`
הכבד מכולם, ובו שלושת החוקים המרכזיים: פתיחת תיק עם בדיקת clearance מול threat_level, הגשת דוח לתיק פתוח בלבד ועל ידי החוקר הנכון, וסגירת תיק רק אם קיים לפחות דוח אחד.

### `services/creatures.service.js`
`listCreatures` (סינון), ו-`getDossier` — שמאחד נתוני SQL עם אגרגציה של דוחות ממונגו. כאן חיים ה-`reduce` וה-`some`.

---

## `src/controllers/` — שכבת ה-HTTP

הכלל ההפוך: קונטרולר יודע רק HTTP ולא יודע כלום על מסדי נתונים. הוא מוציא נתונים מ-`req`, קורא לשירות, ומחזיר סטטוס וגוף תשובה. כל פונקציה היא `async (req, res, next)` עם `try/catch` שמעביר שגיאות ל-`next(err)`.

### `controllers/investigators.controller.js`
מטפל באנדפוינט 1.

### `controllers/creatures.controller.js`
מטפל באנדפוינטים 2 ו-6.

### `controllers/cases.controller.js`
מטפל באנדפוינטים 3, 4, 5 ו-7.

---

## `src/routes/`

### `routes/index.js`
ממפה נתיבים לקונטרולרים: `router.post('/investigators', ...)` וכן הלאה לשבעת האנדפוינטים. מייצא ראוטר אחד ש-`app.js` מחבר תחת `/api`.

---

## `src/middlewares/`

### `middlewares/notFound.js`
נתפס על כל נתיב שלא הותאם, ומחזיר 404 בפורמט אחיד. שלושה פרמטרים.

### `middlewares/errorHandler.js`
**ארבעה פרמטרים** — `(err, req, res, next)`. זה ורק זה מה שגורם לאקספרס לזהות שזה מטפל שגיאות. אם תכתוב שלושה, אקספרס יתייחס אליו כמידלוור רגיל והוא לא ייקרא לעולם. הוא קורא את `err.status` ומשתמש ב-500 כברירת מחדל.

---

## `src/tests/`

### `tests/mocks/cases.repository.mock.js`
רפוזיטורי מזויף עם אותן חתימות פונקציות כמו האמיתי, מעל מערך נתונים בזיכרון. מוגדר עם `mock.fn` כדי שתוכל לבדוק במה הוא נקרא. **מחזיר עותקים ולא מפנה למערך המקורי.**

### `tests/mocks/reports.repository.mock.js`
אותו רעיון לדוחות. חשוב שיהיה בו גם תרחיש של תיק בלי דוחות בכלל, כדי לבדוק את חוק הסגירה.

### `tests/unit/cases.service.test.js`
חמש הבדיקות של חוקי התיקים. `describe` חיצוני לשירות, `describe` פנימי לכל פונקציה, ו-`it` לכל תרחיש.

### `tests/unit/creatures.service.test.js`
שלוש הבדיקות של הדוסייה: ממוצע אמינות, תגיות ללא כפילויות, ויצור בלי דוחות שלא קורס.

---

## סדר בנייה מומלץ

התחל מלמטה למעלה, כי כל שכבה נשענת על הקודמת:

`seed.sql` → `package.json` → `config/env.js` → `db/` → repository אחד → service אחד → controller אחד → `routes` → `app.js` → `server.js`

ברגע שאנדפוינט אחד עובד מקצה לקצה, השאר הם חזרה על אותה תבנית. רק אז תעבור ל-Docker, ורק בסוף לטסטים.
