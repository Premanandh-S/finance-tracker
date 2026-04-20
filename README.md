Sign up page accepts phone and email. For now OTP(by SMS or Email) and password authentications are allowed

There is a page needed for input loan, savings(FD, RD), insurance(term, health, auto and bike insurance) and pension(like EPF and NPS) details.

While input loan details, it should get outstanding balance and interest rate, interest type(fixed vs floating), monthly payment date, institution name, loan number/id and whatever data needed for pull below data in dashboard,

1. Loan number and outstanding balance as of today, next payment date and when it can be closed as per current interest rate and outstanding balance
2. When click the loan number/id, it should open a page where it should display pending payment and outstanding balance for future months until it will be closed.
3. When interest rate gets update, it should recalculate future payments based on updated interest

Note: Both fixed and floating interest should be supported. Interest rate should be inputed for particular range for floating interest

While input savings, it should get institution name, savings id/number, savings types(like FD/RD), amount contributed, start date of savings, maturity date if applicable, one time(like FD) or recurring(RD) and whatever data needed for pull below data in dashboard 

  1. Savings id/number and it’s total value as of today, maturity date and next payment date if it is recurring
  2. When click the savings id/number, if it is recurring, it should show future payments until maturity and expected final value after last payment. If it is one time, show the maturity value and maturity date. 

While input insurance details, it should get institution name, policy number/id, sum assured, add-on details and people included in the coverage and renewal date and last payment details whatever data needed for pull below data in dashboard 

1. Insurance number, sum assured, next renewal date
2. When click on link it should display people covered under the policy and policy/insurance id for each people allocated from insurance company 

While input the pension details, it should get the institution name, pension number/id, monthly contribution  and contribution started date and maturity date if applicable whatever data needed for pull below data in dashboard 

1. Pension number, monthly contribution amount and total contributions so far      

Dashboard: Dashboard should contain below data
1. Savings list and total savings
2. Loans and total debt
3. Insurance
4. Pensions

In future planning to get salary or income details and provide details these details to AI and suggest investment options and retirement planning based on income.

Tech stack
Backend - Ruby on Rails
Frontend - React
DB - Postgres