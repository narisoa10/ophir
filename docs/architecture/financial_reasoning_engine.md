# Financial Reasoning Engine

## Назначение

Financial Reasoning Engine — это слой финансового мышления Ophir.

Financial Knowledge Engine отвечает на вопрос:

```text
Какие финансовые факты существуют, какие модели рассчитываются и какое
состояние пользователя из них следует?
```

Financial Reasoning Engine отвечает на следующий вопрос:

```text
Как профессиональный финансовый консультант использует рассчитанную финансовую
истину, чтобы диагностировать ситуацию, сравнить варианты действий, выбрать
лучший совет, объяснить его и проверить результат?
```

Reasoning Engine не является Flutter feature, Dashboard model, AI prompt или
экраном. Это независимая аналитическая система, которая моделирует процесс
принятия финансовых решений.

Если AI недоступен, Financial Reasoning Engine должен продолжать:

- обнаруживать проблемы;
- строить варианты решений;
- оценивать последствия;
- выбирать рекомендации;
- формировать доказуемые объяснения в структурном виде;
- измерять результат после действия.

AI может сделать объяснение более человечным, но не должен создавать
финансовую истину.

## Почему нужна архитектура сильнее простой цепочки

Предложенная цепочка:

```text
Financial Reality
↓
Financial Knowledge
↓
Financial Models
↓
Financial Reasoning
↓
Detected Problems
↓
Decision Options
↓
Recommended Actions
↓
Expected Outcomes
↓
Learning
```

правильна как общий поток данных, но недостаточна для профессионального
финансового ассистента мирового уровня.

Проблема линейной цепочки в том, что консультант не рассуждает строго один раз
сверху вниз. Он:

- проверяет качество данных до вывода;
- формулирует гипотезы;
- ищет первопричину, а не только симптом;
- сравнивает несколько допустимых действий;
- учитывает ограничения, цели, риск и поведенческую выполнимость;
- объясняет не только выбранный совет, но и отвергнутые альтернативы;
- возвращается к выводам после новых фактов.

Поэтому целевая архитектура должна быть не только pipeline, а
evidence-based decision cycle:

```text
Financial Reality
↓
Financial Knowledge
↓
Financial Model Results
↓
Reasoning Context
↓
Diagnosis
↓
Root Cause Analysis
↓
Decision Options
↓
Trade-off Evaluation
↓
Recommended Actions
↓
Explanation Graph
↓
Expected Outcomes
↓
Measurement Plan
↓
Learning Loop
↺
Reasoning Policy / User Fit / Future Recommendations
```

Эта модель сильнее, потому что она отделяет:

- рассчитанные факты от интерпретации;
- проблему от причины;
- возможное действие от рекомендованного действия;
- финансовый эффект от риска и выполнимости;
- объяснение от AI текста;
- learning качества рекомендаций от изменения финансовой истины.

## Философия Financial Reasoning

Профессиональный финансовый консультант не начинает с совета. Он проходит
последовательность вопросов.

### 1. Что является финансовой реальностью?

Консультант сначала проверяет факты:

- какие деньги есть сейчас;
- какие обязательства уже существуют;
- какие доходы повторяются;
- какие расходы являются обязательными;
- какие расходы управляемы;
- какие цели заявлены пользователем;
- какие ограничения нельзя нарушать;
- какие данные неполные или ненадежные.

Без этого совет может быть красивым, но финансово опасным.

### 2. Что говорят модели?

Дальше консультант смотрит не на отдельные операции, а на модели:

- cash flow;
- savings rate;
- liquidity;
- emergency fund coverage;
- debt burden;
- budget compliance;
- goal feasibility;
- recurring commitments;
- forecast gap;
- financial health score;
- data quality score.

Модель переводит факты в финансовый смысл.

### 3. Что отклоняется от нормы или стратегии?

Проблема появляется не потому, что число выглядит плохо в UI. Проблема
появляется, когда рассчитанное значение отклоняется от:

- математической нормы;
- выбранной стратегии;
- пользовательской цели;
- исторического baseline;
- безопасного диапазона;
- прогнозируемой устойчивости.

### 4. Почему это произошло?

Консультант ищет причину:

- временное событие или устойчивый паттерн;
- доход снизился или расходы выросли;
- проблема в timing или в общей сумме;
- проблема в обязательствах или lifestyle;
- проблема в цели, бюджете, долге или ликвидности;
- проблема надежно подтверждена или данные еще слабые.

### 5. Какие варианты действий существуют?

Профессиональный совет почти никогда не один. Для одной проблемы могут
существовать разные варианты:

- сократить расходы;
- перенести платеж;
- изменить бюджет;
- замедлить цель;
- увеличить взнос в резерв;
- ускорить погашение долга;
- изменить приоритеты;
- ничего не делать и наблюдать, если уверенность низкая.

Reasoning Engine обязан сначала построить набор вариантов, а только потом
выбрать рекомендацию.

### 6. Какой вариант лучший сейчас?

Лучший вариант определяется не максимальным денежным эффектом, а балансом:

- expected financial effect;
- risk reduction;
- urgency;
- confidence;
- effort;
- reversibility;
- user fit;
- strategy alignment;
- impact on other goals;
- time to effect;
- measurability.

### 7. Как это объяснить?

Пользователь должен понимать не только совет, но и логику:

- почему это проблема;
- какие факты к этому привели;
- почему выбран именно этот совет;
- почему другие варианты хуже;
- что изменится после выполнения;
- что будет, если проигнорировать.

## Reasoning Pipeline

### 1. Financial Reality

Входные данные:

- operations;
- accounts;
- balances;
- categories and analytics groups;
- recurring operations;
- budgets;
- goals;
- debts;
- assets;
- taxes;
- bank data after integration;
- user preferences and constraints.

Что анализируется:

- полнота данных;
- свежесть данных;
- ownership;
- currency normalization;
- recorded vs bank reality;
- manual vs imported sources;
- known limitations.

Выводы:

- факты, пригодные для расчетов;
- неполные или сомнительные зоны;
- data quality limitations;
- ограничения на уверенность будущих выводов.

Передается дальше:

- normalized financial facts;
- data quality context;
- source confidence;
- unresolved data gaps.

### 2. Financial Knowledge

Входные данные:

- normalized financial facts;
- domain classifications;
- user strategy;
- household context;
- category analytics meanings;
- financial rules.

Что анализируется:

- смысл финансовых объектов;
- классификация доходов и расходов;
- обязательность и управляемость расходов;
- ликвидность счетов;
- роль целей;
- роль долгов;
- стратегические приоритеты.

Выводы:

- структурированное знание о финансовой жизни пользователя;
- связи между фактами;
- правила, по которым факты должны участвовать в моделях.

Передается дальше:

- model-ready knowledge;
- strategy context;
- classification context;
- user constraints.

### 3. Financial Models

Входные данные:

- model-ready knowledge;
- financial facts;
- strategy context;
- period definitions;
- benchmarks.

Что анализируется:

- cash flow;
- ratios;
- trends;
- liquidity;
- debt burden;
- goal feasibility;
- budget compliance;
- forecast;
- financial health;
- data quality and forecast confidence.

Выводы:

- FinancialModelResult;
- calculated facts;
- expected values;
- actual values;
- deviations;
- model confidence;
- evidence references.

Передается дальше:

- model results;
- calculated facts;
- deviations;
- confidence;
- evidence.

### 4. Reasoning Context

Входные данные:

- model results;
- deviations;
- user strategy;
- known constraints;
- data quality;
- historical outcomes of previous advice.

Что анализируется:

- какие модели важны сейчас;
- какие отклонения заслуживают внимания;
- какие выводы надежны;
- какие выводы требуют уточнений;
- какие предыдущие советы сработали или не сработали.

Выводы:

- актуальный reasoning scope;
- приоритетные зоны анализа;
- допущения;
- ограничения уверенности.

Передается дальше:

- ReasoningStep chain;
- ranked diagnostic focus;
- assumptions.

### 5. Diagnosis

Входные данные:

- reasoning context;
- deviations;
- model confidence;
- evidence.

Что анализируется:

- есть ли проблема;
- насколько она срочная;
- является ли она финансово значимой;
- является ли она повторяющейся;
- угрожает ли она ликвидности, целям или финансовому здоровью.

Выводы:

- Detected Problem;
- severity;
- urgency;
- confidence;
- consequence if ignored;
- required evidence.

Передается дальше:

- structured problems;
- problem evidence;
- severity and urgency.

### 6. Root Cause Analysis

Входные данные:

- detected problems;
- related model results;
- operations and category evidence;
- history;
- forecast.

Что анализируется:

- primary cause;
- contributing causes;
- symptom vs root cause;
- timing issue vs structural issue;
- one-time event vs recurring pattern;
- controllable vs non-controllable drivers.

Выводы:

- root cause hypothesis;
- causal evidence;
- confidence by cause;
- uncertainty.

Передается дальше:

- problem with causal explanation;
- possible intervention points.

### 7. Decision Options

Входные данные:

- problem;
- root cause;
- user constraints;
- strategy;
- model results;
- possible intervention points.

Что анализируется:

- какие действия могут изменить проблему;
- какие действия доступны пользователю;
- какие действия противоречат ограничениям;
- какие действия требуют дополнительных данных;
- какие действия можно измерить.

Выводы:

- option set;
- action type;
- dependencies;
- contraindications;
- expected measurable target.

Передается дальше:

- candidate AdviceOption list.

### 8. Trade-off Evaluation

Входные данные:

- candidate AdviceOption list;
- model results;
- forecast;
- user strategy;
- behavioral history;
- risk tolerance.

Что анализируется:

- expected effect;
- risk;
- opportunity cost;
- effort;
- time to effect;
- reversibility;
- user fit;
- strategy alignment;
- effect on other goals;
- confidence.

Выводы:

- scored options;
- rejected options with reasons;
- trade-off map;
- best option candidate.

Передается дальше:

- ranked decision options;
- recommendation rationale.

### 9. Recommended Actions

Входные данные:

- ranked decision options;
- rationale;
- constraints;
- confidence.

Что анализируется:

- какой совет должен быть главным;
- нужен ли запасной совет;
- должен ли совет быть немедленным или отложенным;
- нужно ли сначала запросить данные;
- нужно ли предупредить пользователя о риске.

Выводы:

- recommended action;
- fallback actions;
- explanation requirements;
- measurement plan.

Передается дальше:

- structured recommendation;
- expected outcome;
- explanation graph;
- learning target.

### 10. Explanation Graph

Входные данные:

- recommended action;
- rejected options;
- problem;
- reasoning steps;
- evidence;
- calculated facts;
- assumptions;
- expected outcome.

Что анализируется:

- какие факты нужны для объяснения;
- какие шаги reasoning нужно показать;
- какие допущения нужно раскрыть;
- какие ограничения данных нужно указать;
- как ответить на вопросы "почему".

Выводы:

- machine-readable explanation;
- user-readable explanation context;
- AI assistant context;
- audit trail.

Передается дальше:

- Dashboard summaries;
- AI context;
- advice details;
- future audit.

### 11. Expected Outcomes

Входные данные:

- recommendation;
- target model;
- forecast;
- expected effect;
- observation window.

Что анализируется:

- какой показатель должен измениться;
- насколько он должен измениться;
- когда эффект должен стать видимым;
- какие внешние факторы могут помешать;
- что считать успехом.

Выводы:

- expected outcome;
- success criteria;
- observation window;
- failure criteria.

Передается дальше:

- measurement plan;
- learning loop.

### 12. Learning Loop

Входные данные:

- recommendation;
- measurement plan;
- observed future model results;
- user response;
- action completion status.

Что анализируется:

- выполнил ли пользователь действие;
- улучшился ли целевой показатель;
- подтвердилось ли предположение;
- была ли рекомендация реалистичной;
- нужно ли изменить будущий ranking.

Выводы:

- outcome assessment;
- advice effectiveness;
- behavioral fit update;
- confidence adjustment for future recommendations.

Передается дальше:

- recommendation quality memory;
- user fit signals;
- future reasoning policy adjustments.

Learning не меняет финансовую истину. Он не переписывает факты, модели или
результаты расчетов. Learning улучшает качество выбора и подачи будущих
рекомендаций.

## Модель ReasoningStep

ReasoningStep — атомарный шаг рассуждения, который связывает факт, модель,
отклонение, вывод и следующий шаг.

```text
ReasoningStep
├── id
├── source
├── assumptions
├── evidence
├── calculatedFacts
├── detectedDeviation
├── confidence
├── explanation
└── nextStep
```

### Поля

`id` — стабильный идентификатор шага reasoning. Нужен для audit trail,
explanation graph и ссылок между выводами.

`source` — источник шага: FinancialModelResult, FinancialProblem,
AdviceOption, Strategy, Forecast, User Constraint, Measurement Result.

`assumptions` — допущения, без которых вывод невалиден. Например:
исторический spending baseline репрезентативен, доход сохранится, recurring
payment повторится, goal priority не изменился.

`evidence` — факты и model results, на которых основан вывод. Evidence должен
быть ссылочным, а не только текстовым.

`calculatedFacts` — численные результаты, использованные в reasoning: actual
value, expected value, ratio, forecast gap, monthly impact, coverage months.

`detectedDeviation` — отклонение от нормы, стратегии, baseline, бюджета, цели
или безопасного диапазона.

`confidence` — уверенность шага. Она зависит от качества данных, стабильности
паттерна, силы evidence, полноты модели и проверенности assumptions.

`explanation` — короткое структурное объяснение шага. Это не AI prose, а
детерминированный смысл: "расходы выше baseline на 23%, поэтому budget risk
повышен".

`nextStep` — ссылка на следующий reasoning step или тип следующего действия:
diagnose, find root cause, generate options, evaluate trade-off, recommend,
measure.

### Почему ReasoningStep важен

ReasoningStep делает объяснения прозрачными:

- каждый вывод можно проследить до фактов;
- каждое допущение видно;
- каждый совет имеет доказательство;
- confidence не скрывается;
- AI получает уже готовую структуру reasoning, а не придумывает логику;
- Dashboard может показывать выводы без выполнения анализа;
- future audit может восстановить, почему совет был выбран.

Правильная структура объяснения:

```text
Fact
-> Model result
-> Deviation
-> Problem
-> Cause
-> Options
-> Trade-off
-> Recommendation
-> Expected outcome
-> Measurement
```

## Процесс выбора рекомендаций

Reasoning Engine не должен выбирать совет из заранее написанного списка
карточек. Он должен пройти полный decision process.

### 1. Определить все возможные действия

Для каждой проблемы система строит action space:

- direct fixes: убрать источник проблемы;
- mitigation: снизить ущерб;
- timing changes: перенести платежи или действия;
- allocation changes: перераспределить деньги;
- strategy changes: изменить приоритеты;
- information actions: запросить данные, если confidence низкий;
- no-action monitoring: наблюдать, если действие преждевременно.

### 2. Оценить последствия каждого действия

Каждый вариант должен иметь expected effect:

- money saved;
- cash gap reduced;
- risk reduced;
- months of runway gained;
- debt interest avoided;
- goal delay reduced;
- financial health score improved;
- forecast confidence improved.

### 3. Оценить риски

Риск рекомендации включает:

- financial risk;
- liquidity risk;
- goal conflict;
- debt risk;
- tax risk;
- behavioral failure risk;
- data uncertainty risk;
- reversibility risk.

### 4. Оценить ожидаемый эффект

Expected effect должен быть измеримым. Нельзя рекомендовать действие только
потому, что оно "выглядит полезным".

Примеры:

- "снизить dining expenses на 15%" — ожидаемая экономия за 30 дней;
- "перенести платеж" — снижение forecast cash gap в конкретную дату;
- "увеличить emergency fund" — рост coverage с 1.2 до 1.6 months;
- "ускорить погашение долга" — снижение будущих interest costs.

### 5. Выбрать лучший вариант

Базовая логика ranking:

```text
recommendation score =
expected effect
* confidence
* urgency
* strategy alignment
* user fit
* reversibility
/ effort
/ risk
```

Формула является концептуальной. Конкретные веса должны зависеть от стратегии
пользователя и типа проблемы.

### 6. Объяснить выбор

Recommendation must include:

- выбранный вариант;
- главный reason;
- supporting evidence;
- expected effect;
- risks;
- rejected alternatives;
- why now;
- how success will be measured.

Если два варианта близки по score, Reasoning Engine должен явно показать
trade-off, а не скрывать неопределенность.

## Система объяснений

Объяснение — это не текст AI. Объяснение — это структурированный reasoning
artifact, который может быть показан пользователю, передан AI или использован в
audit.

### Вопрос: Почему это проблема?

Ответ должен ссылаться на:

- affected model;
- expected value;
- actual value;
- deviation;
- consequence;
- severity.

Пример структуры:

```text
Проблема существует, потому что actual monthly cash flow ниже безопасного
диапазона на X. Если паттерн сохранится, forecast показывает cash gap через Y.
```

### Вопрос: Почему ты так считаешь?

Ответ должен ссылаться на:

- evidence;
- model result;
- confidence;
- assumptions;
- data limitations.

### Вопрос: Какие факты привели к выводу?

Ответ должен перечислять:

- relevant operations;
- relevant categories;
- account balances;
- recurring payments;
- budgets;
- goals;
- debt terms;
- forecast points.

### Вопрос: Почему предлагается именно этот совет?

Ответ должен раскрывать:

- root cause;
- intervention point;
- expected effect;
- urgency;
- user fit;
- confidence;
- measurement plan.

### Вопрос: Почему другой вариант хуже?

Ответ должен сравнивать rejected option:

- lower expected effect;
- higher effort;
- higher risk;
- slower time to effect;
- conflict with goal;
- low confidence;
- weak behavioral fit.

### Вопрос: Что изменится после выполнения?

Ответ должен описывать:

- target metric;
- expected direction;
- expected magnitude;
- expected time window;
- related models that may improve.

### Вопрос: Что будет, если проигнорировать?

Ответ должен описывать:

- forecasted consequence;
- risk growth;
- goal delay;
- additional cost;
- liquidity pressure;
- debt or fee exposure.

## Learning Loop

Learning Loop измеряет качество рекомендации после того, как она была дана.

Он отвечает на вопросы:

- помог ли совет;
- выполнил ли пользователь действие;
- улучшилось ли состояние;
- подтвердилось ли предположение;
- был ли effort реалистичным;
- был ли expected effect завышен или занижен;
- нужно ли изменить future ranking.

### Что Learning может менять

Learning может менять:

- user fit оценку;
- confidence будущих advice templates;
- ranking похожих вариантов;
- предпочтительный тон объяснений;
- assumptions о behavioral feasibility;
- выбор между aggressive и conservative recommendations.

### Что Learning не может менять

Learning не может менять:

- исходные финансовые факты;
- математические результаты моделей;
- правила финансовой истины;
- historical evidence;
- actual balances;
- problem existence, если она подтверждается моделями.

Правильная граница:

```text
Financial Models calculate what is true.
Reasoning chooses what to do.
Learning improves future choices.
AI explains the reasoning.
```

## Роль AI

AI не вычисляет финансовую истину.

AI не определяет проблемы.

AI не рассчитывает модели.

AI не выбирает recommendation priority как источник истины.

AI использует только подготовленный контекст:

- model results;
- reasoning steps;
- detected problems;
- decision options;
- selected recommendation;
- rejected alternatives;
- evidence;
- assumptions;
- confidence;
- measurement plan.

AI может:

- объяснять;
- персонализировать язык;
- вести диалог;
- обучать пользователя;
- отвечать на вопросы;
- переформулировать reasoning под уровень финансовой грамотности;
- задавать уточняющие вопросы, если Reasoning Engine пометил data gaps.

AI не должен:

- придумывать balances;
- определять проблемы без FinancialProblem;
- создавать рекомендации без AdviceOption;
- скрывать low confidence;
- заменять calculation layer;
- давать совет, который противоречит Reasoning Engine.

## Фундаментальные принципы

- Любая рекомендация должна иметь доказательство.
- Любая проблема должна объясняться.
- Любое решение должно быть воспроизводимо.
- Любой вывод должен опираться на математические модели.
- AI не заменяет финансовые вычисления.
- Dashboard показывает выводы, а не выполняет анализ.
- Пользователь должен понимать логику ассистента.
- Reasoning Engine должен уметь сказать "данных недостаточно".
- Не каждый detected deviation требует немедленного совета.
- Хороший совет должен быть проверяемым после выполнения.
- Отвергнутые варианты тоже являются частью reasoning.
- Уверенность должна быть явной, а не спрятанной в тексте.

## Отличие от Financial Knowledge Engine

Financial Knowledge Engine:

- определяет источники финансовых фактов;
- описывает финансовые модели;
- рассчитывает показатели;
- определяет deviations;
- создает model results;
- формирует математическую основу financial health, forecast, problems and
  advice.

Financial Reasoning Engine:

- интерпретирует model results;
- определяет, какие отклонения действительно важны;
- диагностирует проблему и первопричину;
- строит варианты действий;
- сравнивает trade-offs;
- выбирает рекомендацию;
- объясняет логику;
- создает measurement plan;
- улучшает будущий выбор через Learning Loop.

Коротко:

```text
Knowledge Engine knows and calculates.
Reasoning Engine thinks, decides and explains.
```

## Новые архитектурные модели

Предложены следующие модели:

- Reasoning Context — набор model results, constraints, strategy, data quality
  and prior outcomes для текущего цикла анализа.
- ReasoningStep — атомарный шаг рассуждения с source, assumptions, evidence,
  calculatedFacts, deviation, confidence and nextStep.
- Explanation Graph — связный граф фактов, моделей, проблем, причин, вариантов,
  рекомендаций и ожидаемых результатов.
- Root Cause Analysis — слой отделения симптомов от причин.
- Decision Option Set — полный набор допустимых действий до выбора совета.
- Trade-off Evaluation — оценка effect, risk, effort, reversibility, user fit and
  strategy alignment.
- Recommendation Rationale — структурное обоснование выбранного совета.
- Rejected Option Reason — объяснение, почему альтернативы хуже.
- Measurement Plan — критерии проверки результата.
- Learning Loop — корректировка качества будущих рекомендаций без изменения
  финансовой истины.
- Reasoning Policy — правила приоритизации в зависимости от стратегии,
  срочности, риска и пользовательской выполнимости.

## Что уже соответствует текущей архитектуре Ophir

Текущая архитектура уже хорошо поддерживает эту модель:

- `docs/architecture/project_philosophy.md` определяет Ophir как персонального
  финансового ассистента, а не приложение учета расходов.
- `docs/architecture/domain_model.md` закрепляет, что Domain владеет
  финансовым смыслом и вычислениями.
- `docs/architecture/dashboard_architecture.md` запрещает Dashboard считать
  финансовые показатели и описывает Dashboard как потребителя готовой summary.
- `docs/architecture/operation_architecture.md` закрепляет Operations как
  источник финансовых событий, а не UI objects.
- `docs/architecture/category_architecture.md` разделяет `uiGroup` и
  `analyticsGroup`, что необходимо для профессиональной аналитики.
- `docs/architecture/bank_integration_architecture.md` уже разделяет recorded
  balance, bank balance and reconciliation.
- `docs/architecture/financial_knowledge_engine.md` уже задает математическое
  ядро, FinancialProblem, AdviceOption, measurement plan and AI boundary.

Главный пробел: текущая архитектура еще недостаточно явно отделяет
математическое знание от reasoning process. Этот документ закрывает этот
уровень.

## Документы, которые нужно обновить после утверждения

После утверждения Financial Reasoning Engine стоит обновить:

- `docs/README.md` — добавить `architecture/financial_reasoning_engine.md` в
  список ownership документов.
- `docs/architecture/project_philosophy.md` — зафиксировать, что Ophir должен не
  только считать financial truth, но и иметь воспроизводимую модель мышления.
- `docs/architecture/project_rules.md` — добавить короткое правило: советы,
  problems and explanations должны иметь evidence, confidence and reasoning
  trace.
- `docs/architecture/domain_model.md` — добавить ReasoningStep,
  ExplanationGraph, DecisionOption, MeasurementPlan and LearningOutcome как
  целевые domain concepts.
- `docs/architecture/dashboard_architecture.md` — указать, что Dashboard
  отображает outputs Reasoning Engine: problems, recommendation rationale,
  expected outcomes and explanation graph.
- `docs/architecture/financial_knowledge_engine.md` — уточнить границу:
  Knowledge Engine calculates model truth, Reasoning Engine performs diagnosis,
  option comparison and recommendation selection.
- `docs/architecture/feature_workflow.md` — добавить требование для новых
  financial features: указать model result, reasoning step, explanation and
  measurement plan.
- `docs/roadmap/roadmap.md` — разложить развитие Problems Engine, Advice Engine,
  Forecast, Budget, Goals, Financial Health Score and AI Assistant через
  Reasoning Engine.

## Будущие возможности, которые станут проще

Эта архитектура упрощает:

- Problems Engine — проблемы будут следовать из deviations and reasoning steps,
  а не из ручных карточек.
- Advice Engine — советы будут выбираться через option generation and trade-off
  evaluation.
- Budget — бюджетные рекомендации смогут объяснять, какую проблему они решают.
- Goals — goal feasibility сможет участвовать в trade-off decisions.
- Forecast — forecast будет не только графиком будущего, но evidence для
  последствий и ignored-risk explanations.
- Financial Health Score — score сможет объяснять, какие reasoning steps
  ухудшили или улучшили состояние.
- AI Assistant — AI получит structured reasoning context и не будет придумывать
  финансовую логику.
- Dashboard — Dashboard сможет показывать clear next best action без выполнения
  анализа внутри UI.
- Learning — система сможет понимать, какие советы реально помогают конкретному
  пользователю.
- Auditability — любой вывод можно будет восстановить через evidence,
  assumptions, confidence and reasoning chain.

## Запрещено

- Использовать AI как источник финансовой истины.
- Выбирать рекомендацию без сравнения альтернатив.
- Создавать проблему без model result, deviation and evidence.
- Показывать совет без expected outcome.
- Давать совет без measurement plan, если результат измерим.
- Скрывать low confidence.
- Считать Dashboard местом reasoning logic.
- Считать explanation обычным текстом без evidence graph.
- Менять financial facts через Learning Loop.
- Делать Advice Engine списком статичных советов без option evaluation.
