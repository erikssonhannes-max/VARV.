#!/usr/bin/env python3
"""VARV. – bygger data/exercises.json.
Källa: free-exercise-db (github.com/yuhonas/free-exercise-db), public domain.
Kör: python3 scripts/build-exercises.py sökväg/till/exercises.json"""
import json,re,sys
M={"chest":"brost","lats":"rygg","middle back":"rygg","lower back":"rygg","traps":"rygg","shoulders":"axlar","biceps":"biceps","triceps":"triceps",
   "quadriceps":"ben","hamstrings":"ben","glutes":"ben","calves":"ben","adductors":"ben","abductors":"ben","abdominals":"mage","forearms":"underarmar","neck":"axlar"}
# Vanliga namn på gymmet som saknas i källan: namn, muskelgrupp, med vikt
EXTRA=[(n,m,1) for n,m in [
 ("Single Arm Tricep Pushdown","triceps"),("Single Arm Rope Tricep Pushdown","triceps"),("Single Arm Reverse Grip Tricep Pushdown","triceps"),("Single Arm Overhead Cable Tricep Extension","triceps"),("Straight Bar Tricep Pushdown","triceps"),("Cable Tricep Kickback","triceps"),("Dumbbell Tricep Kickback","triceps"),("JM Press","triceps"),("Skull Crusher","triceps"),("EZ Bar Skull Crusher","triceps"),("Dumbbell Skull Crusher","triceps"),("Close Grip Bench Press","triceps"),
 ("Single Arm Cable Curl","biceps"),("Single Arm Dumbbell Curl","biceps"),("Single Arm Preacher Curl","biceps"),("Bayesian Cable Curl","biceps"),("Cable Rope Hammer Curl","biceps"),("Incline Dumbbell Curl","biceps"),("Spider Curl","biceps"),("EZ Bar Curl","biceps"),("Machine Bicep Curl","biceps"),
 ("Single Arm Lat Pulldown","rygg"),("Single Arm Cable Row","rygg"),("Single Arm Dumbbell Row","rygg"),("Single Arm Landmine Row","rygg"),("Single Arm Machine Row","rygg"),("Chest Supported Row","rygg"),("Chest Supported Dumbbell Row","rygg"),("Seal Row","rygg"),("Pendlay Row","rygg"),("Meadows Row","rygg"),("Machine Row","rygg"),("Straight Arm Lat Pulldown","rygg"),("Neutral Grip Lat Pulldown","rygg"),("Wide Grip Lat Pulldown","rygg"),("Close Grip Lat Pulldown","rygg"),("Assisted Pull Up","rygg"),("Weighted Pull Up","rygg"),("Rack Pull","rygg"),("Trap Bar Deadlift","rygg"),("Back Extension","rygg"),("Cable Face Pull","rygg"),("Dumbbell Shrug","rygg"),
 ("Single Arm Cable Chest Press","brost"),("Single Arm Dumbbell Bench Press","brost"),("Single Arm Cable Fly","brost"),("Machine Chest Press","brost"),("Incline Machine Chest Press","brost"),("Pec Deck Fly","brost"),("Low to High Cable Fly","brost"),("High to Low Cable Fly","brost"),("Incline Smith Machine Press","brost"),("Smith Machine Bench Press","brost"),("Weighted Dip","brost"),
 ("Single Arm Lateral Raise","axlar"),("Single Arm Cable Lateral Raise","axlar"),("Single Arm Dumbbell Shoulder Press","axlar"),("Machine Shoulder Press","axlar"),("Machine Lateral Raise","axlar"),("Landmine Press","axlar"),("Single Arm Landmine Press","axlar"),("Reverse Pec Deck","axlar"),("Rear Delt Cable Fly","axlar"),("Arnold Press","axlar"),("Smith Machine Shoulder Press","axlar"),
 ("Single Leg Press","ben"),("Single Leg Extension","ben"),("Single Leg Curl","ben"),("Single Leg Romanian Deadlift","ben"),("Single Leg Hip Thrust","ben"),("Single Leg Calf Raise","ben"),("Barbell Hip Thrust","ben"),("Machine Hip Thrust","ben"),("Hack Squat Machine","ben"),("Pendulum Squat","ben"),("Belt Squat","ben"),("Goblet Squat","ben"),("Smith Machine Squat","ben"),("Bulgarian Split Squat","ben"),("Dumbbell Bulgarian Split Squat","ben"),("Walking Lunge","ben"),("Reverse Lunge","ben"),("Dumbbell Step Up","ben"),("Seated Leg Curl","ben"),("Lying Leg Curl","ben"),("Hip Abduction Machine","ben"),("Hip Adduction Machine","ben"),("Cable Kickback","ben"),("Nordic Hamstring Curl","ben"),("Seated Calf Raise Machine","ben"),("Standing Calf Raise Machine","ben"),
 ("Cable Crunch","mage"),("Hanging Leg Raise","mage"),("Ab Wheel Rollout","mage"),("Pallof Press","mage"),("Decline Sit Up","mage"),("Machine Crunch","mage"),("Wrist Curl","underarmar"),("Reverse Wrist Curl","underarmar")]]
src=json.load(open(sys.argv[1]));out={}
for x in src:
    if x["category"] not in("strength","powerlifting","olympic weightlifting","strongman") or x.get("equipment")=="foam roll":continue
    n=re.sub(r"\s+"," ",x["name"]).strip()
    k="d" if re.search(r"\b(Sled|Walk|Carry|Yoke|Prowler)\b",n) else "t" if x.get("force")=="static" else "r"
    w=0 if x.get("equipment") in(None,"body only") else 1
    out[n.lower()]=[n,M.get(x["primaryMuscles"][0],"axlar"),w,k]
for n,m,w in EXTRA:out.setdefault(n.lower(),[n,m,w,"r"])
rows=sorted(out.values(),key=lambda r:r[0])
ids={}
res=[]
for n,m,w,k in rows:
    i="x-"+re.sub(r"[^a-z0-9]+","-",n.lower()).strip("-")[:48]
    if i in ids:continue
    ids[i]=1
    res.append([i,n,m,w,k])
json.dump(res,open("data/exercises.json","w",encoding="utf8"),ensure_ascii=False,separators=(",",":"))
print(len(res),"övningar")
