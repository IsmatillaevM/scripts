# WinPE Backup

Windows foydalanuvchi profilini WinPE dan (yoki oddiy Windows dan) zaxiralash uchun mustaqil skript. Bitta `.cmd` fayl, hech qanday qo'shimcha dastur kerak emas, Windows yuklanmay qolganda ham tiklash muhitida ishlaydi.

Barcha xabarlar **o'zbek tilida (lotin)** — WinPE da ko'pincha kirill shrifti bo'lmaydi.

Fayl nomi `b.cmd` — konsolda tez yozish uchun qisqa nom.

---

## Mundarija

- [Qanday ishga tushiriladi](#qanday-ishga-tushiriladi)
- [Nimalar nusxalanadi](#nimalar-nusxalanadi)
- [Nimalar nusxalanMAYDI](#nimalar-nusxalanmaydi)
- [Natija](#natija)
- [Talablar va cheklovlar](#talablar-va-cheklovlar)

---

## Qanday ishga tushiriladi

### 1-qadam. Fleshkani tayyorlash

`b.cmd` faylini USB-fleshkaning **ildiziga** qo'ying (papka ichiga emas).

### 2-qadam. Tiklash muhitiga (WinPE) kirish

#### A usul — «Пуск» menyusi orqali (Windows yuklansa)

1. **Shift** tugmasini bosib turing va **Пуск → Питание → Перезагрузка** ni bosing (inglizcha: Start → Power → Restart)
2. Kompyuter **Выбор действия** (Choose an option) menyusiga qayta yuklanadi
3. **Поиск и устранение неисправностей → Дополнительные параметры → Командная строка** ga kiring (Troubleshoot → Advanced options → Command Prompt)
4. Hisobingizni tanlang va parolni kiriting
5. Qora buyruqlar oynasi ochiladi — siz WinPE dasiz

#### B usul — yuklanuvchi WinPE fleshkasi orqali (Windows yuklanmasa)

1. WinPE obrazini boshqa fleshkaga yozing (**Rufus**, **Ventoy** yoki **Win10XPE** yordamida)
2. Shu fleshkadan yuklaning (BIOS da uni Boot Device sifatida tanlang)
3. WinPE ochilganda **Shift + F10** ni bosing — buyruqlar oynasi chiqadi

### 3-qadam. `diskpart` orqali fleshka harfini aniqlash

WinPE da fleshkangizning harfi oddiy Windows dagidan farq qilishi mumkin (`D:`, `E:`, `F:` — kompyuterga bog'liq). Uni bilish uchun quyidagini bajaring:

```cmd
diskpart
```

`DISKPART>` taklifi ochiladi. Kiriting:

```cmd
list volume
```

Shunga o'xshash jadvalni ko'rasiz:

```
  Том ###  Имя  Метка         ФС      Тип        Размер    Состояние  Св
  -------  ---  ------------  ------  ---------  --------  ---------  ---
  Том 0    C    Windows 11    NTFS    Раздел     475 Гб    Исправен
  Том 1         FAT32         Раздел  200 Мб     Исправен  Скр
  Том 2    E                  NTFS    Раздел     765 Мб    Исправен  Скр
  Том 3    D    MY_USB        FAT32   Сменный    14 Гб     Исправен
```

Turi **Сменный** (`Removable`) bo'lgan va hajmi fleshkangizga mos qatorni toping — bu o'sha fleshka. Yuqoridagi misolda harf — `D`.

diskpart dan chiqing:

```cmd
exit
```

### 4-qadam. Skriptni ishga tushirish

Fleshka harfi + `\b` ni kiriting. Yuqoridagi misol uchun:

```cmd
D:\b
```

`.cmd` kengaytmasini yozish shart emas — Windows uni o'zi qo'shadi.

### 5-qadam. Skript savollariga javob berish

Skript barcha disklar jadvalini (raqami, hajmi va metkasi bilan) ko'rsatadi, so'ng so'raydi:

1. **Fleshka raqami** — zaxira qayerga saqlanadi. Tasdiqlashni so'raydi: `Y`.
2. **Windows diski raqami** — qayerdan nusxalanadi (odatda `C:`). Diskda `\Users\` papkasi bo'lishi kerak.
3. **Foydalanuvchi profili** — agar profil bitta bo'lsa, avtomatik tanlanadi.
4. **Papkalar jadvalini har birining hajmi bilan** ko'rsatadi (o'rnatuvchi va vaqtinchalik fayllarsiz — aynan nusxalanadigan narsa), umumiy hajmni va fleshkadagi **bo'sh joyni**. Agar sig'masa — ogohlantiradi va davom etishni so'raydi.
5. **Boshlaymizmi?** — `Y` ni bosing, nusxalash boshlanadi.

Agar ketma-ket 10 marta noto'g'ri raqam kiritilsa, skript to'xtaydi.

### Nusxalash paytida nima ko'rinadi

Ekran tozalanadi va har ~2–3 soniyada bitta jadval qayta chiziladi:

```
 ============================================================================
   ZAXIRALASH JARAYONI  -  Muzaffar
 ============================================================================

   Hozir:          [4/11] Videos
   Nusxalandi:     12450 MB / 41200 MB   - 30%
   [############............................]

   Tezlik:         45.3 MB/s
   O'tgan vaqt:    00:04:35
   Qolgan vaqt:    00:10:34
   Fleshkada joy:  102400 MB

   #   Papka                  Hajm, MB   Holat
   --  ---------------------  ---------  ----------------
    1  Desktop                     5120  tayyor
    2  Documents                   2300  tayyor
    3  Pictures                    4800  tayyor
    4  Videos                     20000  nusxalanmoqda...
    5  Music                        900  kutilmoqda
   ...
 ============================================================================
```

- **Hozir** — hozir qaysi papka nusxalanmoqda, **Nusxalandi** — umumiy hajmdan necha MB nusxalangani va foizi.
- **Tezlik** — o'rtacha tezlik, **Qolgan vaqt** — shu tezlikda qancha vaqt qolgani.
- **Holat**: `kutilmoqda` — navbatda, `nusxalanmoqda...` — nusxalanmoqda, `tayyor` — tayyor, `yo'q` — papka yo'q, `xato` — xatolar bo'ldi (tafsilotlar `_backup.log` da), `joy yo'q` — fleshka to'lgani uchun o'tkazib yuborildi.
- Foiz oyna sarlavhasida ham ko'rinadi.
- Nusxalash ish stolidan (Desktop) boshlanadi. Fleshkada 100 MB dan kam joy qolsa, qolgan papkalar o'tkazib yuboriladi — shuning uchun muhim papkalar birinchi navbatda nusxalanadi.
- Nusxalanayotgan fayllarning yo'llari ekranga chiqmaydi — ular `_backup.log` ga yoziladi.

---

## Nimalar nusxalanadi

### Profil papkalari

- **Desktop, Documents, Pictures, Videos, Music, Favorites, Links** — to'liq.
- **Downloads** — hammasi, o'rnatuvchi fayllar va obrazlardan **tashqari**: `.exe`, `.msi`, `.msix`, `.appx`, `.iso`, `.img`, `.vhd`, `.vhdx`, `.dmg`, `.pkg`, `.deb`, `.rpm`.
- **AppData\Roaming** va **AppData\Local** — to'liq, brauzer va dasturlar **keshlari bilan birga**, faqat `Temp` papkalarisiz.
- **Boshqa papkalar** — profil ildizidagi qolgan hamma narsa: masalan `.cache`, `anaconda3`, `.vscode`, `.gitconfig` va boshqa dastur papkalari va fayllari. `Profil_boshqa\` papkasiga tushadi. Faqat yuqorida allaqachon nusxalangan papkalar va foydalanuvchi reestri fayllari `NTUSER.DAT` nusxalanmaydi.

Keshlar va AppData ko'p joy egallaydi va juda ko'p mayda fayllardan iborat, shuning uchun zaxira katta bo'ladi va nusxalash uzoq davom etadi. Fleshkani zaxira bilan oling.

### Maxsus ma'lumotlar

| Papka | Ichida nima bor |
|---|---|
| `_Bookmarks\` | Chrome va Edge xatcho'plari (`Bookmarks` fayli), Firefox profillari papkasi |
| `_Outlook\` | `Documents\Outlook Files` va `AppData\...\Microsoft\Outlook` dagi `.pst` / `.ost` / `.nst` fayllar |
| `_RDP\` | `Documents\` dagi `.rdp` fayllar va Remote Desktop ilovasi sozlamalari |
| `_SSH\` | `.ssh` papkasi (kalitlar, `known_hosts`, `config`) va `putty_sessions.reg` — PuTTY seanslari |
| `_UserFonts\` | Faqat foydalanuvchi uchun o'rnatilgan shriftlar |
| `_StickyNotes\` | Ish stoli stikerlari: `Modern\` (Windows 10/11) va `Legacy\` (Windows 7/8) |

Tiklash: Outlook — **File → Open & Export → Open Outlook Data File**; PuTTY — `putty_sessions.reg` ni ikki marta bosing.

### Tiklash uchun fayllar (`_SystemInfo\`)

| Fayl / papka | Ichida nima bor |
|---|---|
| `WiFi\` | Ishlab turgan Windows da — parollari ochiq ko'rinishdagi XML profillar. WinPE da — xom XML profillar, ulardagi parollar shifrlangan va faqat o'sha Windows da ochiladi. |
| `hosts` | `Windows\System32\drivers\etc\hosts` faylining nusxasi |

Qolgan hamma narsa (kompyuter haqida ma'lumot, dasturlar ro'yxati, Windows kaliti, natijalar) — `report.html` da, alohida txt fayllar yo'q.

Tiklash:

```cmd
rem Wi-Fi (faqat ishlab turgan Windows dan olingan XML)
netsh wlan add profile filename="E:\...\WiFi\Home_Network.xml"
```

Drayverlar nusxalanmaydi: ularni ishlab chiqaruvchi saytidan qayta o'rnatish osonroq.

---

## Nimalar nusxalanMAYDI

- Downloads dagi **o'rnatuvchi fayllar va obrazlar** (ularni qayta yuklab olish oson)
- **Vaqtinchalik fayllar**: `Temp` / `tmp` papkalari, `*.tmp`, `*.temp` fayllar
- **Papkalarning tizim fayllari**: `Thumbs.db`, `desktop.ini`
- **Foydalanuvchi reestri**: profil ildizidagi `NTUSER.DAT` va unga bog'liq fayllar
- **Savat** (`$Recycle.Bin`) va `System Volume Information`
- **Xizmat profillari**: `Public`, `Default`, `Default User`, `All Users`, `defaultuser0`, `WDAGUtilityAccount`

Istisnolar ro'yxati — `b.cmd` dagi 4-qadam boshidagi `X_STD`, `X_DL` va `X_ROOT` o'zgaruvchilari.

---

## Natija

Hammasi fleshkadagi bitta papkaga tushadi: `D:\Backup_<ism>_YYYYMMDD_HHMM\`.

```
Backup_Muzaffar_20261009_1530\
├── Desktop\  Documents\  Pictures\  Videos\  Music\
├── Favorites\  Links\  Downloads\
├── AppData_Roaming\  AppData_Local\
├── Profil_boshqa\   .cache, anaconda3, .vscode ...
├── _Bookmarks\  _Outlook\  _RDP\  _SSH\  _UserFonts\  _StickyNotes\
├── _SystemInfo\     tiklash uchun Wi-Fi profillari va hosts
├── _backup.log      robocopy ning batafsil jurnali (Unicode): barcha nusxalangan fayllar va xatolar
└── report.html      interaktiv hisobot - birinchi navbatda shuni oching
```

### Interaktiv hisobot `report.html`

Barcha hisobotlar bitta sahifada jamlangan. U har qanday brauzerda ochiladi, internetsiz ishlaydi, yorug' yoki qorong'i mavzuga o'zi moslashadi va telefonda ham yaxshi ko'rinadi.

Chap tomonda — hisobotlar ro'yxati (telefonda — yuqoridagi panel), ba'zilarining yonida hisoblagich bor:

| Bo'lim | Ichida nima bor |
|---|---|
| **Umumiy** | Asosiy raqamlar: qancha nusxalandi, nechta fayl, vaqt, o'rtacha tezlik, tayyor papkalar, xatolar. Zaxiradagi har bir papkaning hajmi, fayl turlari bo'yicha doiraviy diagramma, eng katta 10 fayl. Papkani bosish — uni daraxtda ochadi, turni bosish — shu turdagi fayllar ro'yxatini. |
| **Papkalar** | 11 ta papkaning har biri bo'yicha: reja, haqiqatda nusxalangan hajm, vaqt va holat. |
| **Fayl turlari** | Fayl turlari (hujjatlar, rasmlar, videolar, audio, arxivlar, kod, dastur fayllari, boshqalar) va eng «og'ir» 60 ta kengaytma: soni, hajmi, ulushi. Qatorni bosish — shu fayllar ro'yxati. |
| **Fayllar** | Barcha nusxalangan fayllar: nomi yoki papkasi bo'yicha qidirish, turi, papkasi va hajmi bo'yicha filtrlar (1 MB / 10 MB / 100 MB / 1 GB dan katta), nomi, papkasi, turi, hajmi va sanasi bo'yicha saralash (ustun sarlavhasini bosing). 200 qatordan ko'rsatiladi, «Yana 200 ta» tugmasi yana qo'shadi. |
| **Papka daraxti** | Papkalarni xuddi Explorer dagidek ko'rish: ichki papkalar va fayllar hajmi bo'yicha saralangan, chiziqlar bilan. Bosish — ichiga kirish, yuqoridagi yo'l — orqaga qaytish. |
| **Dasturlar** | O'rnatilgan dasturlar alifbo tartibida, takrorlarsiz, qidiruv bilan. WinPE da Windows diskining reestridan, oddiy Windows da — joriy reestrdan olinadi. |
| **Kompyuter** | Ishlab chiqaruvchi, model, seriya raqami, protsessor, xotira, videokartalar, disklar, BIOS, Wi-Fi tarmoqlari nomlari. Windows kaliti oxirgi 5 belgidan tashqari yashirilgan, «Ko'rsatish» tugmasi uni to'liq ko'rsatadi. |
| **Qo'shimcha** | Xatcho'plar, Outlook, SSH, RDP, shriftlar, stikerlar, hosts, Wi-Fi — nima saqlandi, nima o'tkazib yuborildi. |
| **Xatolar** | Nusxalab bo'lmagan fayllar (2000 qatorgacha; to'liq ro'yxat — `_backup.log` da). |

Fayllar ro'yxati sahifaga joylashtiriladi, shuning uchun katta zaxirada hisobot o'nlab megabayt bo'ladi (600 000 faylga taxminan 30 MB). Sinab ko'rilgan: bunday sahifa bir soniyadan kam vaqtda ochiladi, 600 000 fayl ichida qidirish taxminan 0,3 soniya oladi.

---

## Talablar va cheklovlar

- **Windows 7+** yoki istalgan **WinPE**, yetarli joyi bor fleshka.
- **Administrator huquqlari** — WinPE da ular doim bor. Ularsiz fayllar va reestrning bir qismi o'tkazib yuboriladi.
- **`wmic`** — jadvaldagi disk hajmlari va fleshkadagi bo'sh joy uchun kerak. Agar u bo'lmasa (Windows 11 ning yangi versiyalari), disk harflari baribir topiladi, lekin hajmlar `?` bo'ladi, bo'sh joy esa `0 MB`: skript ma'lumotlar «sig'maydi» deb ogohlantiradi — davom etish uchun `Y` ni bosing. Jarayon jadvali bunda ham ishlaydi, lekin sekinroq yangilanadi: skript nusxalanganini qayta hisoblaydi.
- **`ping`** jadval yangilanishlari orasidagi pauza uchun ishlatiladi. Agar u bo'lmasa, jadval shunchaki tez-tez yangilanadi.
- **Profil hajmi** `robocopy` orqali hisoblanadi va tizim tiliga bog'liq emas.
- **`findstr`, `where`, `timeout` va PowerShell ga bog'liq emas** — WinPE ning qisqartirilgan versiyalarida ular bo'lmasligi mumkin.
- **Brauzer** — hisobotni ko'rish uchun JavaScript yoqilgan istalgan zamonaviy brauzer (Edge, Chrome, Firefox).
- **Xavfsizlik**: zaxirada SSH kalitlari, Wi-Fi profillari (ishlab turgan Windows da — parollar ochiq ko'rinishda) va hisobotda Windows kaliti bo'ladi. Fleshkani ishonchli joyda saqlang.
