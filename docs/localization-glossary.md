# Глоссарий локализации

Языки: немецкий (`de`), португальский Бразилии (`pt-BR`), латиноамериканский испанский (`es-419`). Исходный — английский. Строки — `MySkin/Localizable.xcstrings`, системные запросы — `MySkin/InfoPlist.xcstrings`.

## Обращение
- de — на *du* («deine Haut»), врач — «dein Arzt oder deine Ärztin».
- pt-BR — на *você*, «seu médico».
- es-419 — на *tú*, «tu médico».

## Термины

| EN | de | pt-BR | es-419 |
|---|---|---|---|
| Calm mode | Ruhemodus | Modo calma | Modo calma |
| Flare / Flare mode | Schub / Schubmodus | Crise / Modo crise | Brote / Modo brote |
| flare signs | Schubzeichen | sinais de crise | signos de brote |
| Check-in | Check-in | Registro | Registro |
| Itch | Juckreiz | Coceira | Picazón |
| Body map | Körperkarte | Mapa do corpo | Mapa corporal |
| Trigger | Auslöser | Gatilho | Desencadenante |
| Treatment | Behandlung | Tratamento | Tratamiento |
| Insights (вкладка) | Einblicke | Análises | Análisis |
| Patterns | Muster | Padrões | Patrones |
| Skin impact | Hautbelastung | Impacto na pele | Impacto en la piel |
| Joint check | Gelenk-Check | Checagem das articulações | Revisión de articulaciones |
| Fingertip unit (FTU) | Fingerspitzeneinheit | Unidade de ponta de dedo | Unidad de punta de dedo |
| Self-rated index | Selbst bewerteter Index | Índice autoavaliado | Índice autoevaluado |
| Clear / Mild / Moderate / Severe | Erscheinungsfrei / Leicht / Mittelschwer / Schwer | Limpa / Leve / Moderada / Grave | Limpia / Leve / Moderada / Grave |
| Seek medical care now | Such jetzt ärztliche Hilfe | Procure atendimento médico agora | Busca atención médica ahora |

## Правила
- Медицинская оговорка («discuss with your doctor», «not a diagnosis») переводится в каждом языке одной и той же формулой.
- Препараты — МНН в форме языка (Metotrexato, Adalimumabe), бренды без перевода, только те, что продаются в регионе.
- Названия языков в выборе языка — на самих языках («Deutsch»), не переводятся.
- Множественное число — plural-варианты каталога (`one`/`other`), а не «photo(s)» в коде. Несколько аргументов — substitutions.
- Одно английское слово с разным смыслом — разные ключи с `defaultValue`: `side.front/back` (сторона тела), `uv.*` (уровень UV), `pattern.*` (сила закономерности).
- Слово внутри фразы — `String.inSentence`: строчными буквами, кроме немецкого.
- CSV-экспорт остаётся английским (заголовки и значения — машинный формат).
- Переводы сделаны Claude без вычитки носителем (решение пользователя от 2026-10-17).
