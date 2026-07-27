# לשכת התופעות החריגות — Bureau of Anomalous Phenomena

פרויקט תרגול לקראת המבחן. שרת Express שמנהל את מאגר המידע של לשכה ממשלתית סודית העוסקת בתיעוד יצורים ותופעות בלתי מוסברות: מי החוקרים, אילו יצורים תועדו, אילו תיקים פתוחים, ומה נמצא בשטח.

**זמן בנייה משוער:** 4–6 שעות
**נושאים מכוסים:** Express, SQL (Supabase), MongoDB, Docker + Compose, בדיקות יחידה, ו-JavaScript מודרני

---

## למה שני מסדי נתונים

זו לא גחמה — זו הסיבה שהפרויקט מעניין מבחינה הנדסית.

**SQL (Supabase)** מחזיק את מה שמובנה ויחסי: חוקרים, יצורים, תיקים. יש קשרים ברורים, מפתחות זרים, ואילוצים.

**MongoDB** מחזיק את **דוחות השטח**. כל דוח נראה אחרת — דוח על טביעות רגל מכיל מידות ועומק, דוח על הקלטת קול מכיל תדר ומשך, דוח על מפגש ישיר מכיל עדות מילולית חופשית. אין לזה סכמה קבועה, וזה בדיוק המקרה שבו מונגו מנצח טבלה.

בשלושה מהאנדפוינטים תיאלץ לקרוא משני המסדים בבקשה אחת. זה החלק הכי מלמד בפרויקט.

---

## סכמת SQL (Supabase)

```sql
CREATE TABLE investigators (
  id            SERIAL PRIMARY KEY,
  codename      VARCHAR(50) UNIQUE NOT NULL,
  clearance     INT NOT NULL CHECK (clearance BETWEEN 1 AND 5),
  recruited_at  DATE NOT NULL DEFAULT CURRENT_DATE,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE creatures (
  id               SERIAL PRIMARY KEY,
  name             VARCHAR(100) UNIQUE NOT NULL,
  classification   VARCHAR(50) NOT NULL,   -- aquatic / aerial / subterranean / humanoid / unknown
  threat_level     INT NOT NULL CHECK (threat_level BETWEEN 1 AND 5),
  habitat          VARCHAR(100),
  first_documented DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE cases (
  id              SERIAL PRIMARY KEY,
  creature_id     INT NOT NULL REFERENCES creatures(id),
  investigator_id INT NOT NULL REFERENCES investigators(id),
  status          VARCHAR(20) NOT NULL DEFAULT 'open',  -- open / closed / cold
  opened_at       TIMESTAMP NOT NULL DEFAULT NOW(),
  closed_at       TIMESTAMP
);
```

**נתוני זריעה (seed):** לפחות 4 חוקרים ברמות הרשאה שונות, 6 יצורים ברמות איום 1–5, ו-3 תיקים פתוחים. תכתוב את זה כקובץ `seed.sql` שאתה מריץ פעם אחת ב-SQL Editor של Supabase.

## סכמת MongoDB

קולקשן אחד: `field_reports`

```js
{
  _id: ObjectId,
  case_id: 12,                    // מפנה ל-cases.id ב-SQL
  reported_by: "RAVEN-7",         // codename של החוקר
  submitted_at: ISODate,
  location: { lat: 32.07, lng: 34.85, description: "מנהרת ניקוז נטושה" },
  reliability: 4,                 // 1-5
  tags: ["nocturnal", "tracks"],
  evidence: [                     // מבנה משתנה לפי הסוג — זה כל העניין
    { type: "photo",    resolution: "1920x1080", is_blurry: true },
    { type: "audio",    duration_sec: 47, peak_hz: 18 },
    { type: "physical", sample: "hair", sent_to_lab: false }
  ],
  narrative: "טקסט חופשי מהשטח"
}
```

שים לב: `case_id` הוא מספר מ-SQL, לא ObjectId. אין קשר אמיתי בין המסדים — **אתה** אחראי לוודא שהתיק קיים לפני שאתה כותב דוח. זה שיעור חשוב בפני עצמו.

---

## שבעת האנדפוינטים

| # | Method | Path | מסד | מה מיוחד |
|---|--------|------|-----|----------|
| 1 | POST | `/api/investigators` | SQL | ולידציה |
| 2 | GET | `/api/creatures` | SQL | סינון דרך query params |
| 3 | POST | `/api/cases` | SQL | חוק עסקי בין טבלאות |
| 4 | GET | `/api/cases/:id` | SQL + Mongo | שילוב שני מקורות |
| 5 | POST | `/api/cases/:id/reports` | SQL + Mongo | ולידציה חוצת-מסדים |
| 6 | GET | `/api/creatures/:id/dossier` | SQL + Mongo | אגרגציה |
| 7 | PATCH | `/api/cases/:id/close` | SQL + Mongo | חוק שדורש בדיקה במונגו |

### 1. POST /api/investigators
גיוס חוקר חדש. גוף הבקשה: `codename`, `clearance`.
- שדה חסר → 400
- `clearance` מחוץ לטווח 1–5 → 422
- `codename` שכבר קיים → 409
- הצלחה → 201 עם החוקר שנוצר

### 2. GET /api/creatures
רשימת יצורים, עם סינון אופציונלי: `?classification=aquatic&max_threat=3`
- בלי פרמטרים → הכל
- פרמטר שלא קיים בסכמה → פשוט התעלם, אל תקרוס
- החזר 200 עם מערך, גם אם ריק

### 3. POST /api/cases
פתיחת תיק. גוף: `creature_id`, `investigator_id`.
- יצור או חוקר שלא קיים → 404
- חוקר לא פעיל → 403
- **החוק המרכזי:** אם `investigator.clearance < creature.threat_level` → 403 עם הודעה ברורה. חוקר ברמה 2 לא נשלח לצוד יצור ברמת איום 5.
- ליצור ולחוקר שכבר יש ביניהם תיק פתוח → 409

### 4. GET /api/cases/:id
תמונת מצב מלאה של תיק. מחזיר את התיק מ-SQL, מועשר בפרטי היצור והחוקר, **וכל דוחות השטח שלו ממונגו**, ממוינים מהחדש לישן.
- תיק לא קיים → 404
- אין דוחות → מערך ריק, לא שגיאה

### 5. POST /api/cases/:id/reports
הגשת דוח שטח. גוף: `reported_by`, `location`, `reliability`, `evidence`, `narrative`, `tags`.
- תיק לא קיים ב-SQL → 404
- תיק סגור → 409 (אי אפשר להגיש דוח לתיק סגור)
- `reported_by` חייב להתאים ל-codename של החוקר שמשויך לתיק → 403
- `evidence` חייב להיות מערך עם לפחות פריט אחד, וכל פריט חייב שדה `type` → 422
- הצלחה → 201 עם ה-id של הדוח שנוצר

### 6. GET /api/creatures/:id/dossier
תיק יצור מסכם. מחזיר את פרטי היצור מ-SQL, ובנוסף — מחושב מדוחות השטח במונגו:
- כמה דוחות סה"כ קיימים על היצור הזה (דרך כל התיקים שלו)
- ממוצע ה-`reliability`
- רשימת כל ה-`tags` הייחודיים שהופיעו
- האם קיימת ראיה פיזית כלשהי (`evidence` עם `type: "physical"`) — בוליאני

### 7. PATCH /api/cases/:id/close
סגירת תיק.
- תיק לא קיים → 404
- תיק שכבר סגור → 409
- **החוק:** אי אפשר לסגור תיק בלי לפחות דוח שטח אחד במונגו → 422
- הצלחה → עדכון `status` ל-`closed` ו-`closed_at` לזמן הנוכחי

---

## מבנה קבצים מומלץ

```
anomalies-bureau/
├── docker-compose.yml
├── Dockerfile
├── .dockerignore
├── .env.example
├── package.json
├── seed.sql
└── src/
    ├── server.js                 # הרמת השרת בלבד
    ├── app.js                    # הרכבת express, middlewares, routes
    ├── config/
    │   └── env.js                # קריאה וולידציה של משתני סביבה
    ├── db/
    │   ├── mongo.js              # חיבור מונגו (singleton עם await נכון)
    │   └── supabase.js           # יצירת ה-client
    ├── repositories/
    │   ├── investigators.repository.js
    │   ├── creatures.repository.js
    │   ├── cases.repository.js
    │   └── reports.repository.js   # היחיד שמדבר עם מונגו
    ├── services/
    │   ├── investigators.service.js
    │   ├── cases.service.js
    │   └── creatures.service.js
    ├── controllers/
    │   ├── investigators.controller.js
    │   ├── cases.controller.js
    │   └── creatures.controller.js
    ├── routes/
    │   └── index.js
    ├── middlewares/
    │   ├── errorHandler.js       # ארבעה פרמטרים, אחרון בשרשרת
    │   └── notFound.js
    └── tests/
        ├── mocks/
        │   ├── cases.repository.mock.js
        │   └── reports.repository.mock.js
        └── unit/
            ├── cases.service.test.js
            └── creatures.service.test.js
```

**הכלל שמנחה את המבנה:** ה-controller יודע על HTTP ולא יודע כלום על מסדי נתונים. ה-service יודע חוקים עסקיים ולא יודע מה זה `req` או `res`. ה-repository יודע לדבר עם מסד ולא יודע מה זה חוק עסקי. אם אתה מוצא את עצמך כותב `res.status()` בתוך service — עצור.

כל service נבנה כפונקציית מפעל שמקבלת רפוזיטורי כפרמטר, בדיוק כמו `createUsersService`. זה מה שיאפשר לך לבדוק אותו.

---

## Docker

**Dockerfile** — אימג' לשרת בלבד:
- בסיס `node:20-alpine`
- העתקת `package*.json` והרצת `npm ci` **לפני** העתקת שאר הקוד (שאלת מבחן קלאסית: למה? כי שכבות הקאש)
- `EXPOSE` לפורט
- `CMD` שמריץ את השרת

**docker-compose.yml** — שני שירותים:
- `api` — נבנה מה-Dockerfile, קורא `.env`, תלוי ב-`mongo`
- `mongo` — אימג' רשמי, עם `volume` בשם כדי שהמידע ישרוד `docker compose down`

Supabase רץ בענן ולא בקונטיינר — הוא מגיע דרך משתני סביבה. אם בא לך תרגול נוסף, תוסיף שירות `postgres` מקומי כחלופה ותכתוב את הרפוזיטורי כך שיעבוד מול שניהם.

**`.env.example` צריך להכיל:** `PORT`, `MONGO_URI`, `MONGO_DB_NAME`, `SUPABASE_URL`, `SUPABASE_KEY`. הקובץ `.env` האמיתי נכנס ל-`.gitignore`.

בדיקת קבלה: `docker compose up --build` מרימה הכל, ובקשה לאנדפוינט 2 מחזירה תשובה תקינה.

---

## בדיקות יחידה

`node --test` בלבד, בלי ספריות חיצוניות. `describe` ו-`it`, עם mocks ידניים לרפוזיטורי.

**המינימום הנדרש — שמונה בדיקות:**

ב-`cases.service.test.js`:
1. פתיחת תיק תקין מחזירה id
2. חוקר עם clearance נמוך מרמת האיום → נזרקת שגיאה עם `status` 403
3. יצור לא קיים → 404
4. סגירת תיק בלי דוחות → 422
5. סגירת תיק עם דוח אחד לפחות → מצליחה, ו-`update` נקרא עם `status: "closed"`

ב-`creatures.service.test.js`:
6. dossier מחשב נכון ממוצע reliability
7. dossier מחזיר רשימת tags ללא כפילויות
8. יצור בלי דוחות מחזיר ממוצע 0 ומערך ריק, לא קריסה

**כללי כתיבת המוקים:**
- מוק לעולם לא משנה את המערך המשותף. תמיד מחזיר עותק.
- בכל `it` תאפס את מצב המוק, אחרת סדר הבדיקות ישפיע על התוצאה.
- זכור ש-`mock.calls[0].arguments` הוא **מערך** של הארגומנטים.

---

## חלוקת זמן

| שלב | מה עושים | זמן |
|-----|----------|-----|
| 1 | Supabase: יצירת הטבלאות והרצת seed | 30 דק' |
| 2 | שלד: package.json, app.js, server.js, חיבורים לשני המסדים | 45 דק' |
| 3 | אנדפוינטים 1–2 (SQL בלבד) + middleware לשגיאות | 45 דק' |
| 4 | אנדפוינטים 3–5 (החוקים העסקיים והצלב בין המסדים) | 90 דק' |
| 5 | אנדפוינטים 6–7 (אגרגציה וסגירה) | 60 דק' |
| 6 | Dockerfile + compose והרמה מלאה | 45 דק' |
| 7 | שמונה בדיקות היחידה | 60 דק' |

---

## שתילות מכוונות

הכנתי את הדרישות כך שיאלצו אותך להשתמש בדיוק בחמשת הדברים שסימנו לחזרה. אל תעקוף אותן בלולאת `for`:

- **`some`** — הבדיקה אם קיימת ראיה פיזית באנדפוינט 6
- **`reduce`** — חישוב ממוצע ה-reliability, וגם איסוף ה-tags
- **`find`** — איתור החוקר המתאים, לא `filter`
- **`map`** — הפיכת דוקומנטים ממונגו לצורת התשובה (עם `id` במקום `_id`)
- **spread ו-rest** — הרכבת אובייקט התשובה באנדפוינט 4, ובניית עותקים במוקים
- **closure** — כל service שמקבל רפוזיטורי

---

## הרחבות אם נשאר זמן

- אנדפוינט חיפוש טקסט חופשי ב-`narrative` של הדוחות (`$regex` או text index)
- מיון היצורים ב-dossier לפי "רמת פעילות" — כמה דוחות הוגשו עליהם בחודש האחרון
- middleware פשוט שמדפיס לכל בקשה את המתודה, הנתיב, וכמה מילישניות לקחה
- הגבלה: חוקר לא יכול להחזיק יותר משלושה תיקים פתוחים במקביל
