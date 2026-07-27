-- ============================================
-- Bureau of Anomalous Phenomena — schema + seed
-- Run once in the Supabase SQL Editor.
-- ============================================

-- מוחק הכל ומתחיל מאפס. שורה זו נועדה לפיתוח בלבד.
-- הסדר חשוב: cases תלויה בשתי האחרות, לכן היא נמחקת ראשונה.
DROP TABLE IF EXISTS cases, creatures, investigators CASCADE;

-- ---------- טבלאות ----------

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
  classification   VARCHAR(50) NOT NULL,
  threat_level     INT NOT NULL CHECK (threat_level BETWEEN 1 AND 5),
  habitat          VARCHAR(100),
  first_documented DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE cases (
  id              SERIAL PRIMARY KEY,
  creature_id     INT NOT NULL REFERENCES creatures(id),
  investigator_id INT NOT NULL REFERENCES investigators(id),
  status          VARCHAR(20) NOT NULL DEFAULT 'open',
  opened_at       TIMESTAMP NOT NULL DEFAULT NOW(),
  closed_at       TIMESTAMP
);

-- ---------- נתוני התחלה ----------

INSERT INTO investigators (codename, clearance, recruited_at, is_active) VALUES
  ('RAVEN-7',   5, '2019-03-14', TRUE),
  ('MOTH-2',    3, '2021-07-02', TRUE),
  ('CINDER-9',  2, '2023-01-20', TRUE),
  ('HOLLOW-4',  4, '2018-11-05', FALSE);

INSERT INTO creatures (name, classification, threat_level, habitat, first_documented) VALUES
  ('Grey Sifter',      'subterranean', 1, 'מערכות ביוב עירוניות',  '2015-06-11'),
  ('Hollow Piper',     'humanoid',     3, 'יערות נשירים',          '2011-09-30'),
  ('Tidewalker',       'aquatic',      4, 'שפכי נהרות',            '2008-02-17'),
  ('Ashen Kite',       'aerial',       2, 'צוקי חוף',              '2017-04-23'),
  ('The Long Quiet',   'unknown',      5, 'לא ידוע',               '2003-12-01'),
  ('Bellows Hound',    'subterranean', 3, 'מכרות נטושים',          '2020-08-08');

-- שים לב: כל שיוך כאן מכבד את חוק ההרשאות —
-- clearance של החוקר גדול או שווה ל-threat_level של היצור.
INSERT INTO cases (creature_id, investigator_id, status) VALUES
  (2, 1, 'open'),   -- Hollow Piper  (3) → RAVEN-7  (5)
  (4, 2, 'open'),   -- Ashen Kite    (2) → MOTH-2   (3)
  (1, 3, 'open');   -- Grey Sifter   (1) → CINDER-9 (2)