import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import fsolve
#https://www.overleaf.com/project/62a7d5859cc70051564b5834

monthly_payment = 5
number_of_payments = 240
anual_IRR = 12 #in %


def main():
    
    
    plt.rcParams.update({'font.size': 20})
    plot_panel_value()
    plot_interrest_curve()
    
    SolarT_value = estimate_SolarT_value(monthly_payment, number_of_payments, anual_IRR)
    print('Panel listing value %.0fUSD' % SolarT_value)


def estimate_SolarT_value(monthly_payment, number_of_payments, anual_interrest_rate):
    
    r = anual_interrest_rate/12/100
    N = number_of_payments
    m0 = monthly_payment
    SolarTvalue = m0*((1+r)**N - 1)/(r * (1+r)**N)
    
    return SolarTvalue


def estimate_SolarT_interrest(monthly_payment, number_of_payments, listing_price):
    
    N = number_of_payments
    m0 = monthly_payment
    
    def myFunction(r):
        F = listing_price - m0*((1+r)**N - 1)/(r * (1+r)**N)
        return F
    
    zGuess = np.array([0.01])
    r_sol = fsolve(myFunction,zGuess)
    

    ''' solving analytically with sympa did not work
    from sympy import symbols, solve
    r = symbols('r')
    expr = listing_price - m0*((1+r)**N - 1)/(r * (1+r)**N)
    sol = solve(expr)

    print(sol)
    
    r_sol = sol[0]
    '''
    
    
    interrest_rate = r_sol[0]*12*100
    
    return interrest_rate


def plot_panel_value():
    SolarT_value = []
    generated_profits = []
    n_ = np.arange(number_of_payments +1)[::-1]
    for n in n_:
        val = estimate_SolarT_value(monthly_payment, n, anual_IRR)
        SolarT_value.append(val)
        generated_profits.append((number_of_payments-n)*monthly_payment)
        
    SolarT_value = np.array(SolarT_value)
    generated_profits = np.array(generated_profits)
    portfolio_value = SolarT_value + generated_profits
    
    plt.figure(figsize=(10,5))
    plt.title('Portfolio Graph graph for a panel with %sUSD monthly payments and a %s%% IRR' % (monthly_payment, anual_IRR), fontsize = 17)
    plt.plot(SolarT_value, label = 'SolarT value', color='red', ls = '--', lw=1.5)
    plt.plot(generated_profits, label = 'Acumulated profit', color='blue', ls = '--', lw=1.5)
    plt.plot(portfolio_value, label = 'Portfolio value', color='gold', lw=3)
    plt.xlabel('Months')
    plt.ylabel('USD')
    plt.legend(fontsize=14)
    plt.xlim(0,number_of_payments)
    plt.ylim(0, np.max(portfolio_value)*1.1)
    plt.savefig('portfolio_value.png')
    plt.show()
    
    
def plot_interrest_curve():
    
    listing_prices = np.linspace(250,1000)
    effective_IRR = []
    for price in listing_prices:
        IRR = estimate_SolarT_interrest(monthly_payment, number_of_payments, price)
        effective_IRR.append(IRR)
        
    effective_IRR = np.array(effective_IRR)
    
    plt.figure(figsize=(10,5))
    plt.title('IRR graph for a panel with %sUSD monthly payments and %s payments' % (monthly_payment, number_of_payments), fontsize = 17)
    plt.plot(listing_prices, effective_IRR, color='black', lw=3)
    plt.xlabel('Listing price panel [USD]')
    plt.ylabel('Effective annual IRR [%]')
    plt.grid()
    plt.savefig('IRR.png')
    plt.show()


main()




