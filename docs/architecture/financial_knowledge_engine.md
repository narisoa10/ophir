# Financial Knowledge Engine

## Назначение

Financial Knowledge Engine — фундаментальная финансовая система знаний Ophir.

Ophir не должен строиться вокруг экранов, виджетов или текущего набора функций.
Ophir должен строиться вокруг финансового состояния пользователя: активов,
обязательств, денежных потоков, рисков, целей, ограничений, стратегий,
поведенческих паттернов и прогнозируемых последствий.

Этот документ описывает математическое ядро, из которого должны следовать:

- financial models;
- deviations;
- financial problems;
- advice;
- forecasts;
- explanations;
- financial health score;
- AI assistant context.

Главный принцип:

```text
Financial facts
-> Financial models
-> Deviations
-> Problems
-> Advice
-> Outcome measurement
-> Explanation
```

AI не является источником финансовой истины. Все расчеты, проблемы и
рекомендации должны быть воспроизводимы без AI.

## Базовые принципы

### Финансовая истина строится из фактов

Первичными являются финансовые факты: операции, счета, активы, обязательства,
доходы, расходы, повторяющиеся платежи, цели, бюджеты, налоги, курсы валют,
банковские данные и пользовательские правила.

Derived данные не должны становиться первичной истиной. Statistics, Dashboard,
Financial Health Score, Problems и Advice являются результатами вычислений.

### Модель должна отвечать как консультант

Каждый вывод Ophir должен отвечать на вопрос:

```text
Как профессиональный финансовый консультант пришел бы к этому выводу,
анализируя финансовую жизнь человека?
```

Это означает, что вывод должен иметь:

- измеримый показатель;
- норму или ожидаемое значение;
- отклонение;
- причинные данные;
- уверенность;
- прогнозируемое последствие;
- возможное действие.

### Финансовые модели стабильнее функций

Dashboard, Budget, Goals, Statistics, Cash Flow, Forecast, Investments, Taxes и
AI Assistant могут меняться. Модели ликвидности, cash flow, долговой нагрузки,
нормы сбережений, устойчивости дохода, net worth и достижимости целей должны
оставаться фундаментом.

## Financial Knowledge Sources

Источники знаний — это сущности, из которых Ophir получает финансовые факты.
Они не равны экранам приложения.

### User / Household

Представляет владельца финансового пространства: одного человека, семью,
домохозяйство или будущую shared finance модель.

Хранит:

- user identity;
- base currency;
- locale;
- household structure;
- financial preferences;
- risk tolerance;
- planning horizon;
- life stage;
- dependents;
- privacy and ownership boundaries.

Делает возможным:

- нормализацию валют;
- персональные financial benchmarks;
- family cash flow;
- household net worth;
- goal prioritization;
- risk-based recommendations.

Используется:

- Financial Health Score;
- Goals;
- Taxes;
- AI Assistant;
- family planning;
- wealth management.

### Accounts

Представляют финансовые контейнеры: cash, checking, savings, credit card,
brokerage, loan account, mortgage account, business account, tax account.

Хранят:

- account type;
- owner;
- currency;
- initial balance;
- recorded balance;
- bank balance after integration;
- credit limit;
- interest rate when applicable;
- liquidity class;
- visibility in calculations;
- institution metadata after bank integration.

Делают возможным:

- balance calculation;
- liquidity analysis;
- cash runway;
- reconciliation;
- debt utilization;
- account allocation;
- net worth.

Используются:

- Dashboard;
- Cash Flow;
- Bank Integration;
- Debt;
- Investments;
- Forecast;
- Financial Health Score.

### Operations

Представляют финансовое событие: income, expense, transfer, investment buy/sell,
debt payment, tax payment, refund, fee, interest, adjustment.

Хранят:

- amount;
- currency;
- type;
- date and posting date;
- account;
- counterparty or merchant;
- category;
- analytics group;
- source: manual or bank imported;
- recurrence link;
- tags;
- confidence for imported/enriched data;
- tax relevance;
- business/freelance relevance.

Делают возможным:

- cash flow;
- category analytics;
- budget compliance;
- recurring commitment detection;
- anomaly detection;
- tax categorization;
- behavioral analysis.

Используются:

- Dashboard;
- Statistics;
- Budget;
- Forecast;
- Tax reports;
- AI Assistant;
- Advice Engine.

### Categories

Представляют смысл операции для пользователя и аналитики. Category должна
разделять UI grouping и analytical meaning.

Хранят:

- user-facing name;
- icon;
- uiGroup;
- analyticsGroup;
- essential/flexible/lifestyle classification;
- tax classification;
- business classification;
- default recurrence expectation;
- sensitivity or privacy level.

Делают возможным:

- expense ratio;
- essential ratio;
- flexible ratio;
- lifestyle inflation;
- budget scopes;
- tax reports;
- financial behavior analysis.

Используются:

- Statistics;
- Budget;
- Forecast;
- Financial Health Score;
- Advice;
- AI explanations.

### Analytics Groups

Представляют устойчивую аналитическую классификацию расходов и доходов,
независимую от UI.

Хранят:

- group id;
- financial meaning;
- ratio class;
- benchmark ranges;
- strategy role;
- forecast behavior;
- tax/business role.

Делают возможным:

- comparison with strategy;
- model-level aggregation;
- spending structure analysis;
- professional benchmarks;
- rule-based problem detection.

Используются:

- Financial Models;
- Decision Engine;
- Budget;
- Forecast;
- Financial Health Score.

### Income Sources

Представляют источники поступлений: salary, freelance, business, dividends,
interest, rental income, transfers, gifts, refunds.

Хранят:

- source type;
- expected amount;
- frequency;
- variability;
- reliability;
- employer/client concentration;
- tax withholding;
- currency;
- start/end dates.

Делают возможным:

- income stability;
- income concentration risk;
- tax planning;
- forecasted inflows;
- goal feasibility.

Используются:

- Forecast;
- Cash Flow;
- Taxes;
- Goals;
- Financial Health Score;
- Advice.

### Expenses

Расходы являются операциями с отрицательным влиянием на cash flow, но в
Financial Knowledge Engine они дополнительно классифицируются по экономической
природе.

Хранят через Operations и Categories:

- amount;
- frequency;
- necessity level;
- controllability;
- recurrence;
- commitment duration;
- discretionary nature;
- inflation sensitivity.

Делают возможным:

- fixed vs variable cost;
- essential vs discretionary split;
- burn rate;
- lifestyle inflation;
- optimization advice.

Используются:

- Budget;
- Cash Flow;
- Forecast;
- Problems;
- Advice.

### Recurring Operations

Представляют повторяющиеся финансовые обязательства и поступления.

Хранят:

- recurrence rule;
- expected amount;
- variance tolerance;
- next expected date;
- end date;
- linked operations;
- missed occurrence state;
- subscription or bill classification.

Делают возможным:

- upcoming cash flow;
- subscription load;
- fixed monthly cost;
- missed payment detection;
- forecast baseline;
- commitment risk.

Используются:

- Calendar;
- Forecast;
- Dashboard;
- Budget;
- Advice.

### Budgets

Представляют финансовые ограничения или план распределения ресурсов.

Хранят:

- scope: category, analytics group, account, total, goal;
- period;
- planned amount;
- rollover rule;
- strategy mapping;
- hard/soft limit;
- priority;
- user overrides.

Делают возможным:

- budget compliance;
- remaining allowance;
- burn pace;
- overspending detection;
- strategy adherence.

Используются:

- Budget;
- Problems;
- Advice;
- Forecast;
- Financial Health Score.

### Goals

Представляют будущий финансовый результат: emergency fund, debt payoff, purchase,
investment target, retirement, tax reserve, education, business reserve.

Хранят:

- target amount;
- current amount;
- target date;
- priority;
- required contribution;
- funding accounts;
- risk tolerance;
- inflation assumption;
- return assumption;
- dependency on other goals.

Делают возможным:

- goal progress;
- goal feasibility;
- required saving rate;
- trade-off analysis;
- opportunity cost;
- forecast impact.

Используются:

- Goals;
- Forecast;
- Advice;
- Financial Health Score;
- AI Assistant.

### Strategies

Представляют выбранную финансовую политику: 50/30/20, 60/20/20, debt-first,
emergency-first, FIRE, personal strategy.

Хранят:

- target ratios;
- allowed ranges;
- priority order;
- debt policy;
- savings policy;
- investment policy;
- emergency fund target;
- budget allocation rules;
- exception rules.

Делают возможным:

- comparison of actual vs intended behavior;
- strategy drift detection;
- advice prioritization;
- model weighting.

Используются:

- Decision Engine;
- Budget;
- Financial Health Score;
- Advice.

### Calendar

Представляет временную структуру финансовой жизни.

Хранит:

- pay dates;
- bill dates;
- tax deadlines;
- goal milestones;
- debt due dates;
- subscription renewal dates;
- seasonal periods;
- user-specific events.

Делает возможным:

- short-term liquidity forecast;
- cash gap detection;
- seasonality analysis;
- timing advice;
- payment planning.

Используется:

- Forecast;
- Cash Flow;
- Upcoming;
- Taxes;
- Advice.

### Debts

Представляют обязательства пользователя: credit cards, loans, mortgage, student
loans, installment plans, overdrafts.

Хранят:

- principal;
- interest rate;
- minimum payment;
- due date;
- term;
- credit limit;
- amortization schedule;
- collateral;
- tax deductibility;
- payoff strategy.

Делают возможным:

- debt ratio;
- debt-to-income;
- utilization;
- interest burden;
- payoff forecast;
- avalanche/snowball comparison.

Используются:

- Debt Management;
- Financial Health Score;
- Forecast;
- Advice;
- Net Worth.

### Savings

Представляют накопленные ликвидные резервы.

Хранят:

- linked accounts;
- liquidity tier;
- purpose;
- target coverage;
- restrictions;
- currency;
- expected yield.

Делают возможным:

- emergency fund coverage;
- liquidity score;
- runway;
- savings rate;
- reserve allocation.

Используются:

- Goals;
- Financial Health Score;
- Forecast;
- Advice.

### Investments

Представляют инвестиционные активы и стратегии.

Хранят:

- holdings;
- asset class;
- quantity;
- cost basis;
- market value;
- expected return;
- volatility;
- fees;
- tax wrapper;
- allocation target;
- dividend/interest income.

Делают возможным:

- net worth;
- portfolio allocation;
- risk exposure;
- rebalancing need;
- long-term goal feasibility;
- tax-aware decisions.

Используются:

- Investments;
- Goals;
- Forecast;
- Taxes;
- Financial Health Score.

### Taxes

Представляют налоговые обязательства и налоговые последствия операций.

Хранят:

- jurisdiction;
- income classification;
- deductible categories;
- estimated tax rate;
- withholding;
- tax deadlines;
- realized gains/losses;
- business expenses;
- carry forwards.

Делают возможным:

- tax reserve calculation;
- after-tax income;
- deductible expense tracking;
- tax liability forecast;
- investment tax planning.

Используются:

- Taxes;
- Forecast;
- Freelance;
- Business;
- Advice.

### Exchange Rates

Представляют правила пересчета валют.

Хранят:

- currency pair;
- rate;
- timestamp;
- source;
- precision;
- historical rate.

Делают возможным:

- base currency normalization;
- multi-currency net worth;
- FX gain/loss;
- international spending analysis;
- forecast in base currency.

Используются:

- Accounts;
- Operations;
- Investments;
- Net Worth;
- Forecast.

### Assets

Представляют то, чем пользователь владеет: cash, deposits, investments, real
estate, vehicles, business equity, receivables, valuables.

Хранят:

- asset type;
- value;
- valuation date;
- liquidity;
- ownership share;
- income generation;
- depreciation/appreciation assumptions;
- collateral status.

Делают возможным:

- net worth;
- liquidity-adjusted net worth;
- wealth allocation;
- solvency analysis.

Используются:

- Net Worth;
- Investments;
- Goals;
- Financial Health Score.

### Liabilities

Представляют финансовые обязательства: loans, credit balances, taxes payable,
leases, unpaid invoices, family obligations.

Хранят:

- liability type;
- outstanding amount;
- interest rate;
- due dates;
- minimum payment;
- legal priority;
- secured/unsecured status.

Делают возможным:

- net worth;
- solvency;
- debt ratios;
- cash flow commitments;
- risk analysis.

Используются:

- Debt;
- Forecast;
- Financial Health Score;
- Advice.

### Net Worth Snapshots

Представляют состояние капитала пользователя во времени.

Хранят:

- timestamp;
- total assets;
- total liabilities;
- net worth;
- liquid net worth;
- currency;
- valuation confidence.

Делают возможным:

- wealth trend;
- progress toward financial independence;
- balance sheet health;
- long-term forecast validation.

Используются:

- Dashboard;
- Statistics;
- Investments;
- Financial Health Score.

### Family, Business, Freelance Contexts

Представляют разные финансовые контуры, которые могут принадлежать одному
пользователю, но требуют разных правил анализа.

Хранят:

- context type;
- owners;
- linked accounts;
- linked operations;
- tax rules;
- shared obligations;
- income volatility;
- business cash reserve target;
- reimbursement rules.

Делают возможным:

- separation of personal/business cash flow;
- household planning;
- freelance tax reserve;
- business runway;
- client concentration risk.

Используются:

- Taxes;
- Forecast;
- Advice;
- Financial Health Score;
- AI Assistant.

## Financial Models

Financial Model — воспроизводимое вычисление, которое превращает финансовые
факты в показатель. Каждая модель должна возвращать значение, период, единицы,
источники данных, confidence и ссылки на evidence.

### Cash Flow

Математическая идея: измеряет чистое движение денег за период.

Входные данные:

- income operations;
- expense operations;
- transfers excluded or separated;
- accounts;
- currency rates.

Формула:

```text
net cash flow = total income - total expenses
```

Единицы: money per period.

Период пересчета: daily, weekly, monthly, yearly, rolling 30/90/365 days.

Зависит от: Operations, Categories, Accounts, Exchange Rates.

Используется: Dashboard, Statistics, Budget, Forecast, Problems, Advice.

### Operating Cash Flow

Идея: отделяет обычную финансовую жизнь от разовых движений капитала.

Формула:

```text
operating cash flow =
recurring income + regular income - recurring expenses - regular expenses
```

Единицы: money per period.

Период: monthly and rolling 90 days.

Зависит от: Cash Flow, Recurring Operations, income/expense classification.

Используется: Forecast, Financial Health Score, goal feasibility.

### Income Stability

Идея: оценивает надежность дохода.

Входные данные: income by source, dates, variance, recurrence, employer/client
concentration.

Принцип:

```text
income stability = f(variance, recurrence reliability, source concentration)
```

Высокая вариативность и зависимость от одного клиента снижают показатель.

Единицы: score 0..100 or coefficient.

Период: monthly, rolling 3/6/12 months.

Зависит от: Income Sources, Operations, Calendar.

Используется: Forecast, Financial Health Score, Advice, Goals.

### Income Growth Rate

Идея: измеряет динамику дохода.

Формула:

```text
income growth = (income current period - income baseline period) / income baseline period
```

Единицы: percent.

Период: monthly, quarterly, yearly.

Зависит от: Income Sources, Cash Flow.

Используется: Forecast, career/freelance advice, Financial Health Score.

### Income Concentration Risk

Идея: оценивает риск зависимости от одного источника дохода.

Формула:

```text
largest income source share = largest source income / total income
```

Единицы: percent or risk score.

Период: rolling 3/6/12 months.

Зависит от: Income Sources.

Используется: Financial Health Score, Advice, freelance/business analysis.

### Savings Rate

Идея: доля дохода, которая не потребляется.

Формула:

```text
savings rate = (income - expenses) / income
```

Для профессиональной версии может использоваться after-tax income и исключение
debt principal/investment transfers по правилам стратегии.

Единицы: percent.

Период: monthly, yearly, rolling 90/365 days.

Зависит от: Cash Flow, Taxes, Transfers, Goals.

Используется: Financial Health Score, Goals, Forecast, Advice.

### Expense Ratio

Идея: показывает, какая часть дохода уходит на расходы.

Формула:

```text
expense ratio = total expenses / total income
```

Единицы: percent.

Период: monthly and rolling.

Зависит от: Cash Flow.

Используется: Budget, Financial Health Score, Problems.

### Essential Ratio

Идея: доля дохода, уходящая на необходимые расходы.

Формула:

```text
essential ratio = essential expenses / income
```

Единицы: percent.

Период: monthly.

Зависит от: Category.analyticsGroup, Cash Flow.

Используется: Strategy comparison, Budget, Financial Health Score.

### Flexible Ratio

Идея: доля расходов, которые можно относительно быстро изменить.

Формула:

```text
flexible ratio = flexible expenses / income
```

Единицы: percent.

Период: monthly.

Зависит от: Categories, Operations.

Используется: Advice prioritization, budget optimization.

### Lifestyle Ratio

Идея: измеряет discretionary/lifestyle spending.

Формула:

```text
lifestyle ratio = lifestyle expenses / income
```

Единицы: percent.

Период: monthly and rolling 90 days.

Зависит от: Analytics Groups, Cash Flow.

Используется: Financial Health Score, behavioral advice, strategy drift.

### Lifestyle Inflation

Идея: определяет, растут ли discretionary расходы быстрее дохода.

Формула:

```text
lifestyle inflation =
growth(lifestyle expenses) - growth(income)
```

Единицы: percentage points.

Период: quarterly, yearly.

Зависит от: Lifestyle Ratio, Income Growth Rate.

Используется: Advice, long-term planning, Financial Health Score.

### Burn Rate

Идея: скорость потребления денег при отсутствии дохода.

Формула:

```text
burn rate = average monthly essential + fixed + committed expenses
```

Единицы: money per month.

Период: monthly, rolling 3/6 months.

Зависит от: Essential Ratio, Recurring Commitments, Expense classification.

Используется: Emergency Fund Coverage, Forecast, Financial Health Score.

### Liquidity

Идея: оценивает доступность денег без продажи долгосрочных активов.

Формула:

```text
liquidity = liquid assets / short-term obligations
```

Дополнительно:

```text
liquid net worth = liquid assets - short-term liabilities
```

Единицы: ratio and money.

Период: daily after accounts, monthly before bank integration.

Зависит от: Accounts, Assets, Liabilities, Calendar.

Используется: Dashboard, Forecast, Financial Health Score, Problems.

### Emergency Fund Coverage

Идея: на сколько месяцев хватит резервов.

Формула:

```text
emergency coverage months = liquid emergency savings / monthly essential burn rate
```

Единицы: months.

Период: monthly or whenever balance changes materially.

Зависит от: Savings, Burn Rate, Liquidity.

Используется: Financial Health Score, Goals, Advice.

### Cash Runway

Идея: сколько времени пользователь может выполнять обязательства при текущем
cash flow и ликвидности.

Формула:

```text
cash runway = liquid assets / max(0, monthly negative operating cash flow)
```

Если operating cash flow положительный, runway может считаться stable.

Единицы: months.

Период: monthly, forecast refresh.

Зависит от: Liquidity, Operating Cash Flow.

Используется: Forecast, freelance/business planning, Problems.

### Debt Ratio

Идея: доля обязательств относительно активов.

Формула:

```text
debt ratio = total liabilities / total assets
```

Единицы: percent.

Период: monthly.

Зависит от: Assets, Liabilities.

Используется: Net Worth, Financial Health Score, Advice.

### Debt-to-Income

Идея: долговая нагрузка относительно дохода.

Формула:

```text
DTI = monthly debt payments / gross or after-tax monthly income
```

Единицы: percent.

Период: monthly.

Зависит от: Debts, Income Sources, Taxes.

Используется: Debt advice, Financial Health Score, affordability analysis.

### Interest Burden

Идея: сколько дохода теряется на проценты.

Формула:

```text
interest burden = monthly interest paid / monthly income
```

Единицы: percent.

Период: monthly.

Зависит от: Debts, Operations.

Используется: Advice, debt payoff strategy, Financial Health Score.

### Credit Utilization

Идея: степень использования доступного кредитного лимита.

Формула:

```text
credit utilization = credit balance / credit limit
```

Единицы: percent.

Период: daily or bank sync.

Зависит от: Accounts, Debts, Bank Integration.

Используется: Debt, Financial Health Score, Advice.

### Budget Compliance

Идея: сравнивает фактические расходы с планом.

Формула:

```text
budget usage = actual spending / budgeted amount
budget deviation = actual spending - expected spending by date
```

Единицы: percent and money.

Период: budget period, with daily progress.

Зависит от: Budgets, Operations, Calendar.

Используется: Budget, Problems, Advice.

### Budget Burn Pace

Идея: определяет, расходуется ли бюджет слишком быстро.

Формула:

```text
burn pace = spent share / elapsed period share
```

Единицы: ratio.

Период: daily inside active budget period.

Зависит от: Budget Compliance, Calendar.

Используется: early warning problems, Dashboard, Advice.

### Goal Progress

Идея: измеряет продвижение к цели.

Формула:

```text
goal progress = current saved amount / target amount
```

Единицы: percent.

Период: whenever linked accounts/operations change.

Зависит от: Goals, Accounts, Operations.

Используется: Goals, Dashboard, Financial Health Score.

### Goal Feasibility

Идея: оценивает, достижима ли цель в срок.

Формула:

```text
required monthly contribution =
(target amount - current amount) / months remaining

feasibility =
available monthly surplus / required monthly contribution
```

Для инвестиционных целей учитываются expected return, volatility and inflation.

Единицы: ratio, percent, probability band.

Период: monthly and on goal changes.

Зависит от: Goal Progress, Forecast, Savings Rate, Investments.

Используется: Goals, Advice, Forecast.

### Net Worth

Идея: баланс капитала пользователя.

Формула:

```text
net worth = total assets - total liabilities
```

Единицы: money.

Период: monthly, daily when automated balances exist.

Зависит от: Assets, Liabilities, Exchange Rates.

Используется: Dashboard, Investments, Financial Health Score, Forecast.

### Forecast

Идея: оценивает вероятное будущее состояние денег.

Входные данные:

- current balances;
- recurring income;
- recurring expenses;
- budgets;
- goals;
- seasonal patterns;
- planned events;
- debt schedules;
- tax obligations.

Принцип:

```text
future balance[t] =
current balance
+ expected inflows[t]
- expected outflows[t]
+/- expected asset/liability changes[t]
```

Единицы: money over time, probability ranges.

Период: rolling daily for 30/90 days, monthly for 12+ months.

Зависит от: Cash Flow, Calendar, Recurring Operations, Goals, Debts, Taxes.

Используется: Dashboard, Problems, Advice, Goals, Financial Health Score.

### Forecast Confidence

Идея: показывает надежность прогноза.

Принцип:

```text
confidence = f(data completeness, recurrence certainty, income stability,
historical variance, bank sync freshness)
```

Единицы: score 0..100.

Период: each forecast run.

Зависит от: Forecast, Income Stability, Data Quality.

Используется: AI explanations, Problems, Advice.

### Subscription Load

Идея: измеряет нагрузку подписок и автоматических списаний.

Формула:

```text
subscription load = monthly subscription cost / monthly income
```

Единицы: percent and money per month.

Период: monthly.

Зависит от: Recurring Operations, Categories.

Используется: Advice, Budget, Financial Health Score.

### Recurring Commitments

Идея: сумма обязательных повторяющихся платежей.

Формула:

```text
recurring commitments =
sum(expected recurring expenses classified as committed)
```

Единицы: money per month.

Период: monthly and forecast horizon.

Зависит от: Recurring Operations, Calendar.

Используется: Forecast, Burn Rate, Financial Health Score.

### Monthly Fixed Cost

Идея: минимальная стоимость текущего образа жизни.

Формула:

```text
monthly fixed cost = rent/mortgage + utilities + insurance + debt minimums
+ committed subscriptions + other fixed obligations
```

Единицы: money per month.

Период: monthly.

Зависит от: Recurring Commitments, Debts, Categories.

Используется: Emergency Fund, Forecast, Advice.

### Variable Cost

Идея: расходы, которые меняются от поведения пользователя.

Формула:

```text
variable cost = total expenses - fixed costs
```

Единицы: money per period.

Период: monthly.

Зависит от: Expenses, Fixed Cost classification.

Используется: Budget, Advice, anomaly detection.

### Anomaly Score

Идея: оценивает необычность операции, категории или периода.

Принцип:

```text
anomaly score = deviation from historical baseline adjusted for seasonality
```

Методы могут включать z-score, percentile deviation, robust median absolute
deviation and rule-based thresholds.

Единицы: score 0..100.

Период: per operation, category, period.

Зависит от: Operations, Categories, Seasonality, Historical Baselines.

Используется: Problems, Insights, AI explanations.

### Seasonality Index

Идея: учитывает, что некоторые месяцы или события всегда дороже.

Формула:

```text
seasonality index[period] =
average spending in comparable periods / average normal spending
```

Единицы: ratio.

Период: monthly, yearly event-based.

Зависит от: Historical Operations, Calendar.

Используется: Forecast, anomaly detection, budget planning.

### Data Quality Score

Идея: оценивает, насколько данным можно доверять.

Принцип:

```text
data quality = f(categorization completeness, account coverage,
bank sync freshness, duplicate risk, missing dates, currency completeness)
```

Единицы: score 0..100.

Период: continuous.

Зависит от: Operations, Accounts, Bank Integration, Categories.

Используется: Forecast Confidence, Problem confidence, AI boundaries.

### Reconciliation Difference

Идея: измеряет расхождение между recorded и bank balances.

Формула:

```text
reconciliation difference = bank balance - recorded balance
```

Единицы: money.

Период: bank sync.

Зависит от: Accounts, Bank Integration, Operation matching.

Используется: Bank Integration, Problems, Advice.

### Tax Reserve Need

Идея: оценивает сумму, которую нужно отложить на налоги.

Формула:

```text
tax reserve need = taxable income * estimated tax rate - withholding - paid taxes
```

Единицы: money.

Период: monthly, quarterly, yearly.

Зависит от: Taxes, Income Sources, Business/Freelance operations.

Используется: Taxes, Forecast, Advice.

### Investment Allocation Drift

Идея: измеряет отклонение портфеля от целевой структуры.

Формула:

```text
allocation drift = actual asset class weight - target asset class weight
```

Единицы: percentage points.

Период: portfolio update.

Зависит от: Investments, Strategy.

Используется: Investments, Advice, Goals.

### Financial Health Score

Идея: агрегирует ключевые показатели в объяснимую оценку здоровья финансов.

Принцип:

```text
health score =
weighted score(
cash flow,
liquidity,
emergency coverage,
debt burden,
savings rate,
budget discipline,
goal feasibility,
income stability,
data quality
)
```

Единицы: score 0..100 with component breakdown.

Период: monthly and on major changes.

Зависит от: all core models.

Используется: Dashboard, Advice, AI Assistant, long-term progress.

## Financial Decision Engine

Decision Engine превращает математические модели в выводы. Он не начинается со
списка проблем. Он начинается с сравнения фактического финансового состояния с
ожидаемым, стратегическим, историческим и прогнозным состоянием.

### Decision Inputs

Decision Engine сравнивает модели с:

- user strategy: 50/30/20, 60/20/20, personal strategy;
- budgets;
- goals;
- historical baselines;
- seasonality;
- recurring operations;
- forecast;
- user rules;
- bank data and reconciliation state;
- professional benchmarks;
- data quality and confidence.

### Нормы и ожидания

Для каждого model result система должна уметь получить expected value:

```text
expected value =
strategy target
or budget target
or goal-required value
or historical baseline
or seasonal baseline
or forecasted value
or professional benchmark
or user-defined rule
```

Один показатель может иметь несколько норм. Например, расходы на жилье можно
сравнить с:

- бюджетом пользователя;
- долей дохода;
- историческим уровнем;
- прогнозом до конца месяца;
- стратегией 50/30/20.

### Формирование отклонений

Отклонение формируется, когда detected value достаточно отличается от expected
value:

```text
absolute deviation = detected value - expected value
relative deviation = absolute deviation / expected value
severity = f(relative deviation, money impact, time urgency, reversibility)
confidence = f(data quality, model confidence, evidence strength)
```

Отклонение не всегда является проблемой. Оно становится FinancialProblem, если
имеет финансовый риск, ухудшает достижение цели, нарушает стратегию, создает
ликвидный разрыв, повышает долговую нагрузку или требует действия.

### Причинная цепочка

Decision Engine должен хранить причинность:

```text
model result -> deviation -> evidence -> financial consequence -> problem
```

Пример:

```text
Lifestyle Ratio = 42%
Expected by strategy = 30%
Deviation = +12 percentage points
Evidence = restaurants, shopping, subscriptions
Consequence = monthly savings shortfall
Problem = lifestyle spending above strategy
```

### Приоритет проблемы

Проблемы ранжируются не по эмоциональному тексту, а по расчету:

```text
problem priority =
severity * confidence * financial impact * urgency * actionability
```

Где:

- severity показывает размер отклонения;
- confidence показывает надежность вывода;
- financial impact показывает денежный эффект;
- urgency показывает временной риск;
- actionability показывает, есть ли реалистичное действие.

## FinancialProblem Model

FinancialProblem — универсальная модель обнаруженной финансовой проблемы.
Новые типы проблем должны добавляться через новые rules/models, а не через
изменение ядра.

```text
FinancialProblem
├── id
├── type
├── sourceModel
├── category
├── severity
├── priority
├── confidence
├── expectedValue
├── detectedValue
├── deviation
├── unit
├── period
├── explanation
├── consequence
├── evidence
├── relatedOperations
├── relatedCategories
├── relatedAccounts
├── relatedBudgets
├── relatedGoals
├── relatedDebts
├── relatedForecast
├── suggestedActions
├── detectedAt
├── expiresAt
├── status
└── resolutionState
```

### Поля

`id` — стабильный идентификатор проблемы.

`type` — тип проблемы, например `budget_overspend`, `cash_gap_risk`,
`low_emergency_fund`, `income_instability`. Ядро не должно зависеть от
конкретного списка типов.

`sourceModel` — модель, которая обнаружила отклонение: Cash Flow, Budget
Compliance, Forecast, Liquidity, Debt-to-Income.

`category` — область проблемы: cash_flow, budget, debt, liquidity, goals,
taxes, investments, data_quality, behavior.

`severity` — насколько серьезно отклонение.

`priority` — порядок обработки с учетом срочности, эффекта и actionability.

`confidence` — уверенность, основанная на качестве данных и надежности модели.

`expectedValue` — норма, план, прогноз или benchmark.

`detectedValue` — фактически найденное значение.

`deviation` — абсолютное и относительное отклонение.

`unit` — money, percent, months, score, count.

`period` — период, к которому относится проблема.

`explanation` — машинно сформированное объяснение причины.

`consequence` — что произойдет, если ничего не делать.

`evidence` — факты, из которых сделан вывод.

`relatedOperations`, `relatedCategories`, `relatedAccounts`, `relatedBudgets`,
`relatedGoals`, `relatedDebts`, `relatedForecast` — связи с источниками.

`suggestedActions` — ссылки на рекомендации Advice Engine.

`detectedAt`, `expiresAt` — жизненный цикл проблемы.

`status` — active, acknowledged, dismissed, resolved, expired.

`resolutionState` — как система проверяет, исчезла ли проблема.

### Почему модель расширяема

Ядро знает не конкретные проблемы, а универсальную структуру:

```text
source model + expected value + detected value + deviation + evidence
```

Чтобы добавить новый тип проблемы, нужно добавить:

- модель или rule, который производит model result;
- правило сравнения с expected value;
- mapping в FinancialProblem;
- advice templates.

Не нужно менять Dashboard, AI, Advice Engine или общий формат Problems.

## Advice Engine

Advice Engine превращает FinancialProblem в возможные действия.

### Несколько рекомендаций на одну проблему

Одна проблема почти всегда имеет несколько решений.

Пример: отрицательный monthly cash flow может иметь рекомендации:

- сократить discretionary expenses;
- пересмотреть подписки;
- перенести крупную покупку;
- увеличить доход;
- изменить срок цели;
- временно снизить goal contribution.

Advice Engine должен хранить не один текст, а набор AdviceOption.

```text
AdviceOption
├── id
├── problemId
├── actionType
├── expectedEffect
├── effort
├── timeToEffect
├── risk
├── userFit
├── confidence
├── dependencies
├── tradeOffs
├── measurementPlan
└── priority
```

### Расчет приоритета рекомендации

```text
advice priority =
expected financial effect
* confidence
* urgency alignment
* user fit
* reversibility
/ effort
```

Факторы:

- денежный эффект;
- скорость эффекта;
- влияние на цели;
- риск невыполнения;
- соответствие стратегии;
- поведенческая реалистичность;
- наличие данных для проверки.

### Выбор лучшего совета

Лучший совет — не обязательно самый большой по денежному эффекту. Он должен
быть:

- достаточно эффективным;
- выполнимым;
- своевременным;
- объяснимым;
- проверяемым;
- не противоречащим более важным целям.

Decision Engine должен поддерживать trade-off analysis. Например, совет
"погасить долг быстрее" может конфликтовать с "создать emergency fund".
Приоритет определяется стратегией пользователя, ликвидностью и процентной
ставкой долга.

### Ожидаемый эффект

Каждая рекомендация должна иметь измеримый expected effect:

```text
expected effect =
money saved
or risk reduced
or months gained
or debt interest avoided
or goal feasibility improved
or forecast gap reduced
```

Примеры:

- cancel subscription: saves $12/month;
- reduce restaurants by 20%: saves estimated $80/month;
- move payment date: reduces projected cash gap by $300;
- increase emergency savings: improves coverage from 1.2 to 1.6 months.

### Проверка результата

После рекомендации Ophir должен создать measurement plan:

```text
measurement plan =
target model + expected direction + observation window + success criteria
```

Пример:

```text
Advice: reduce discretionary dining by 15%
Target model: Lifestyle Ratio
Window: next 30 days
Success: dining expenses <= historical baseline * 0.85
```

Если совет помог, проблема получает resolutionState `improved` или `resolved`.
Если не помог, Advice Engine должен предложить следующий вариант или снизить
confidence в поведенческой применимости совета.

## Место AI

AI не является источником финансовой истины.

AI не должен вычислять:

- balances;
- cash flow;
- ratios;
- problems;
- forecast;
- financial health score;
- advice priority;
- tax liability;
- investment metrics.

AI должен использовать только подготовленный financial context:

- model results;
- detected problems;
- evidence;
- advice options;
- user strategy;
- confidence;
- known limitations.

AI может:

- объяснять ситуацию человеческим языком;
- переформулировать рекомендации;
- отвечать на вопросы пользователя;
- сравнивать варианты, уже рассчитанные системой;
- помогать понять trade-offs;
- персонализировать тон;
- превращать evidence в понятное объяснение;
- задавать уточняющие вопросы, когда данных недостаточно.

Правильная граница:

```text
Financial Engine calculates truth.
AI explains truth.
```

Если AI недоступен, Ophir должен продолжать рассчитывать модели, проблемы,
советы и прогнозы. Потеря AI может ухудшить качество объяснений, но не должна
ломать финансовую аналитику.

## Этапы развития

### Этап 1: можно реализовать на текущей базе

Основано на:

- Operations;
- Categories;
- Category.analyticsGroup;
- Recurring Operations;
- account initial balances, если уже доступны;
- manual recorded data.

Возможные модели:

- Cash Flow;
- Expense Ratio;
- Essential Ratio;
- Flexible Ratio;
- Lifestyle Ratio;
- Savings Rate;
- Recurring Commitments;
- Subscription Load;
- Monthly Fixed Cost estimate;
- Variable Cost;
- simple Burn Rate;
- simple Forecast from recurring operations;
- Anomaly Score with limited history;
- Data Quality Score;
- basic FinancialProblem;
- basic AdviceOption;
- rule-based Insights.

Ограничения:

- recorded balance, not bank balance;
- прогноз с низкой confidence без банковской полноты;
- долги, налоги, инвестиции и net worth только частично или вручную;
- budget compliance невозможен без полноценной Budget модели;
- goal feasibility ограничена без Goals.

### Этап 2: требует Accounts

Добавляет:

- reliable recorded balance;
- account-level liquidity;
- account allocation;
- transfers without double counting;
- cash runway;
- reconciliation-ready model.

Новые модели:

- Liquidity;
- Liquid Net Worth subset;
- Account Coverage;
- Balance Trend;
- Reconciliation Difference after bank integration.

### Этап 3: требует Budgets

Добавляет:

- expected spending by period;
- budget burn pace;
- overspending detection;
- plan vs actual;
- strategy-to-budget mapping.

Новые модели:

- Budget Compliance;
- Budget Burn Pace;
- Budget Forecast;
- Budget Risk;
- Budget Adjustment Advice.

### Этап 4: требует Goals

Добавляет:

- goal progress;
- goal feasibility;
- required monthly contribution;
- priority trade-offs;
- savings allocation.

Новые модели:

- Goal Progress;
- Goal Feasibility;
- Goal Funding Gap;
- Goal Delay Impact;
- Opportunity Cost.

### Этап 5: требует Bank Integration

Добавляет:

- bank balance;
- imported transactions;
- pending/posted state;
- provider account data;
- better merchant detection;
- better recurring detection;
- reconciliation.

Новые модели:

- Reconciliation Difference;
- Duplicate Risk;
- Bank Sync Freshness;
- Merchant-level Spending;
- Real Cash Availability;
- Forecast Confidence improvement.

### Этап 6: требует Debts

Добавляет:

- structured liabilities;
- interest rates;
- amortization;
- minimum payments;
- payoff planning.

Новые модели:

- Debt Ratio;
- Debt-to-Income;
- Interest Burden;
- Credit Utilization;
- Payoff Forecast;
- Avalanche/Snowball Comparison.

### Этап 7: требует Investments

Добавляет:

- assets beyond cash;
- market values;
- allocation;
- return and volatility assumptions;
- long-term planning.

Новые модели:

- Net Worth;
- Investment Allocation Drift;
- Portfolio Risk;
- Goal Probability;
- Rebalancing Need.

### Этап 8: требует Taxes

Добавляет:

- after-tax income;
- tax reserve;
- deductible expenses;
- estimated liabilities;
- freelance/business planning.

Новые модели:

- Tax Reserve Need;
- Effective Tax Rate;
- After-Tax Cash Flow;
- Deduction Coverage;
- Quarterly Tax Forecast.

### Этап 9: требует AI

AI нужен не для вычислений, а для:

- conversational explanations;
- personalized coaching;
- Q&A over financial context;
- natural-language scenario comparison;
- user education;
- clarification prompts.

AI не должен быть prerequisite для Financial Models, Problems, Advice или
Forecast.

## Дополнительные профессиональные модели

Чтобы Ophir стал профессиональным финансовым ассистентом, со временем стоит
добавить следующие модели.

### Affordability Model

Оценивает, может ли пользователь позволить себе покупку без ухудшения
ликвидности, целей и долговой нагрузки.

### Opportunity Cost Model

Показывает, от какой цели или будущего капитала пользователь отказывается,
выбирая текущее действие.

### Scenario Planning

Сравнивает несколько будущих траекторий:

- keep current behavior;
- reduce discretionary spending;
- increase income;
- accelerate debt payoff;
- delay goal;
- invest surplus.

### Risk Capacity

Оценивает, сколько финансового риска пользователь может выдержать с учетом
ликвидности, дохода, долгов, dependents и горизонта целей.

### Behavioral Drift

Определяет устойчивое отклонение поведения от намерений пользователя:
стратегии, бюджета, целей или собственных правил.

### Merchant Concentration

Находит зависимость расходов от конкретных продавцов или сервисов.

### Fee Drag

Измеряет, сколько пользователь теряет на банковских комиссиях, процентах,
инвестиционных комиссиях и late fees.

### Inflation Exposure

Оценивает, какая часть расходов чувствительна к инфляции: housing, food,
transport, utilities, insurance.

### Financial Independence Runway

Оценивает, сколько лет расходов покрывает liquid/investable net worth.

### Insurance Coverage Gap

В будущем может оценивать риск недостаточного страхового покрытия, если Ophir
будет хранить insurance policies.

### Estate / Beneficiary Readiness

Долгосрочная модель для wealth management: наличие beneficiaries, ownership
structure, emergency access and estate planning readiness.

## Отчет по архитектурным выводам

### 1. Новые архитектурные модели

Предложены:

- Financial Knowledge Source;
- Financial Model;
- Financial Model Result;
- Decision Engine;
- FinancialProblem;
- AdviceOption;
- Measurement Plan;
- Forecast Confidence;
- Data Quality Score;
- Strategy comparison layer;
- Scenario Planning layer.

### 2. Фундаментальные вычисления

Фундаментальными являются:

- Cash Flow;
- Operating Cash Flow;
- Income Stability;
- Savings Rate;
- Expense Ratios;
- Burn Rate;
- Liquidity;
- Emergency Fund Coverage;
- Debt Ratio;
- Debt-to-Income;
- Budget Compliance;
- Goal Feasibility;
- Net Worth;
- Forecast;
- Financial Health Score;
- Data Quality Score.

Они должны жить в domain/services, а не в UI, Dashboard или AI.

### 3. Модели, зависящие от будущих функций

Зависят от Accounts:

- Liquidity;
- accurate balances;
- account allocation;
- cash runway.

Зависят от Budgets:

- Budget Compliance;
- Budget Burn Pace;
- budget-based problems.

Зависят от Goals:

- Goal Progress;
- Goal Feasibility;
- Goal Funding Gap.

Зависят от Bank Integration:

- bank balance;
- reconciliation;
- duplicate risk;
- merchant analytics;
- high-confidence recurring detection.

Зависят от Debts:

- DTI;
- Interest Burden;
- Credit Utilization;
- Payoff Forecast.

Зависят от Investments:

- full Net Worth;
- allocation drift;
- portfolio risk;
- long-term goal probability.

Зависят от Taxes:

- after-tax cash flow;
- tax reserve;
- effective tax rate;
- deductible expense analytics.

Зависят от AI:

- conversational explanation;
- personalized narrative;
- natural-language Q&A.

### 4. Документы, которые нужно обновить после утверждения

После утверждения этой архитектуры стоит обновить:

- `docs/architecture/domain_model.md` — добавить Financial Knowledge Engine,
  Financial Models, FinancialProblem, AdviceOption и Strategy как целевые domain
  concepts.
- `docs/architecture/dashboard_architecture.md` — указать, что Dashboard
  потребляет outputs Financial Knowledge Engine, а не собственные insight rules.
- `docs/architecture/operation_architecture.md` — расширить роль Operations как
  источника финансовых фактов для model results, problems and advice.
- `docs/architecture/category_architecture.md` — закрепить, что
  `analyticsGroup` является входом для ratios, strategy comparison and problem
  detection.
- `docs/architecture/bank_integration_architecture.md` — связать reconciliation,
  bank balance and imported operations с Financial Knowledge Engine.
- `docs/architecture/project_philosophy.md` — сослаться на Financial Knowledge
  Engine как математический фундамент ассистента.
- `docs/roadmap/roadmap.md` — разложить развитие по этапам Financial Models.

### 5. Соответствие существующей архитектуры Ophir

Уже хорошо соответствует:

- разделение Domain, Presentation, UI, Repository;
- запрет финансовых формул в UI;
- идея, что Statistics являются derived output;
- разделение `uiGroup` и `analyticsGroup`;
- признание Dashboard ассистентским экраном, а не набором карточек;
- разделение recorded balance и bank balance;
- запрет provider categories как источника аналитической истины;
- признание reconciliation domain behavior.

Требует развития:

- явная модель Financial Model Result;
- единая модель FinancialProblem;
- Advice Engine с expected effect and measurement plan;
- Strategy model;
- Forecast Confidence and Data Quality Score;
- полноценная модель Accounts, Assets, Liabilities and Net Worth;
- связь Budget, Goals, Forecast и Financial Health Score через общие модели;
- строгая граница AI как explanation layer, not calculation layer.

## Запрещено

- Строить Problems как вручную написанный список карточек.
- Вычислять финансовые показатели в Dashboard UI.
- Использовать AI как источник балансов, проблем или рекомендаций.
- Смешивать recorded balance и bank balance без reconciliation.
- Делать budget, goals, forecast and health score независимыми features без
  общего математического ядра.
- Использовать UI categories вместо `Category.analyticsGroup` для аналитики.
- Добавлять новую финансовую функцию без указания модели, входных данных,
  формулы, confidence and evidence.
