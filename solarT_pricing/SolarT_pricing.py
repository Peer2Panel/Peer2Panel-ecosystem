import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.optimize import fsolve
import sys
#https://www.overleaf.com/project/62a7d5859cc70051564b5834

monthly_payment = 5.25
number_of_payments = 240
anual_IRR_book = 10 #in %


def main():
    
    
    plt.rcParams.update({'font.size': 20})
    generate_IRR_map_old()
    generate_IRR_map_final()
    #generate_IRR_map()
    
    #sys.exit()
    
    
    plot_panel_value()
    plot_interrest_curve()
    
    SolarT_value = estimate_SolarT_value(monthly_payment, number_of_payments, anual_IRR_book)
    print('Panel listing value %.0fUSD' % SolarT_value)
    
    target_listing_price = 420
    IRR = estimate_SolarT_interrest(monthly_payment, number_of_payments, target_listing_price)
    print('IRR %.1f%% for Panel listing value %.0fUSD' % (IRR,SolarT_value))
    
    
    
def generate_IRR_map():
    #2D storage of IRR because it does not have analytical form
    
    
    number_of_payments_array = np.arange(100,30*12)
    Panel_price_array = np.linspace(50,400, num=100)

    store_array = np.zeros((len(number_of_payments_array),len(Panel_price_array)))
    for ni, N in enumerate(number_of_payments_array):
        for pi, price in enumerate(Panel_price_array):

            IRR = estimate_SolarT_interrest(1, N, price)
            store_array[ni,pi] = IRR
            
    #https://jakevdp.github.io/PythonDataScienceHandbook/04.12-three-dimensional-plotting.html
    X, Y = np.meshgrid(Panel_price_array, number_of_payments_array)
    Z = store_array
    plt.figure(figsize=(13,10))
    ax = plt.axes(projection='3d')
    ax.xaxis.labelpad=30
    ax.yaxis.labelpad=30
    ax.zaxis.labelpad=30
    #ax.plot_wireframe(X, Y, Z, color = 'black')
    ax.plot_surface(X, Y, Z, rstride=1, cstride=1,
                cmap='viridis', edgecolor='none')
    
    ax.set_xlabel('Panel price [USD]')
    ax.set_ylabel('Number of payments')
    ax.set_zlabel('Annual IRR[%]')
    #ax.set_zlim(0,100)
    plt.tight_layout()
    plt.show()
    
    
    
def generate_IRR_map_final():
    
    #Build initial map
    number_of_payments_array = np.arange(1,1001)
    IRR_array = np.linspace(-10,40, num=100)
    panel_value_array = np.zeros((len(number_of_payments_array),len(IRR_array)))
    for ni, N in enumerate(number_of_payments_array):
        for ai, IRR in enumerate(IRR_array):
            r = IRR/12/100
            SolarT_value_over_m0 = ((1+r)**N - 1)/(r * (1+r)**N)
            panel_value_array[ni,ai] = SolarT_value_over_m0
            
    X, Y = np.meshgrid(IRR_array, number_of_payments_array)
    Z = panel_value_array
    
    #print(Z[:,0])
    #print(Y[:,0])
    #print(countour1.shape)
    
    
    #print(Z[:,0])
    #print(Z[:,-1])
    
    plt.figure(figsize=(9,5))
    plt.plot(Z[:,0],Y[:,0], color='black', lw=2)
    plt.fill_between(Z[:,0],Y[:,0], color = 'red', alpha=0.2)
    plt.plot(Z[:,-1],Y[:,-1], color='black', lw=2)
    plt.fill_between(Z[:,-1],1e4,Y[:,-1], color = 'green', alpha=0.2)
    plt.xlim(1,np.max(Z[:,0]))
    plt.ylim(1,np.max(Y[:,-1]))
    plt.annotate('IRR < -10%', (1000,10.3), color = 'red')
    plt.annotate('IRR > 40%', (1.2,200), color = 'green')
    plt.ylabel('Number of payments')
    plt.xlabel('Panel price / monthly payment')
    plt.xscale('log')
    plt.yscale('log')
    plt.show()
            
    #Build map where for undefined values
    x0 = np.linspace(np.min(Y) , np.max(Y), num=501)
    y0 = np.linspace(np.nanmin(np.ma.masked_invalid(np.log10(Z))) , np.nanmax(np.ma.masked_invalid(np.log10(Z))), num=501)
    X0,Y0 = np.meshgrid(x0, y0)
    Z0 = np.zeros((len(y0),len(x0)))
    
    for xi, x in enumerate(x0):
        for yi, y in enumerate(y0):
            nwherex = np.argmin(np.abs(number_of_payments_array - x))
            Panel_values = panel_value_array[nwherex,:]
            
            nwherey = np.argmin(np.abs(np.log10(Panel_values) - y))
            
            if nwherey == 0:
                IRR = -10
            elif nwherey == len(Panel_values)-1:
                IRR = 40
            else:
                IRR = IRR_array[nwherey]

            Z0[xi,yi] = IRR
            
            
    x_line = np.arange(len(x0))
    y_line_0 = np.zeros(len(y0))
    y_line_book = np.zeros(len(y0))
    for xi in x_line:
        n0 = np.argmin(np.abs(Z0[xi,:]-0))
        nbook = np.argmin(np.abs(Z0[xi,:]-anual_IRR_book))
        y_line_0[xi] = n0
        y_line_book[xi] = nbook
    
    plt.figure(figsize=(9,7))
    plt.imshow(Z0, cmap='inferno', origin='lower', vmin = -11, vmax = 41)
    plt.plot(y_line_0, x_line, color = 'gray', lw=3, label = 'IRR = 0%')
    plt.plot(y_line_book, x_line, color = 'white', lw=3, label = 'Book Value (%s%% IRR)' % anual_IRR_book)
    cbar = plt.colorbar()
    cbar.set_label('Annual IRR [%]',size=18)
    plt.ylabel('Number of payments')
    plt.xlabel('Panel price / monthly payment')
    nticks = [0,100,200,300,400,500]
    plt.yticks(nticks, x0[nticks].astype(int))
    plt.xticks(nticks, np.power(10,y0[nticks]).astype(int))
    plt.legend(fontsize=14)
    plt.show()
    
    #plot 0% and 15% line
    
    sys.exit()
            
    
    df = pd.DataFrame()
    df['remaining_payments'] = Y0
    df['panel_price_over_monthly_payment'] = np.power(10,X0)
    df['IRR'] = Z0
    pd.to_csv(df)
    
    
    
    

def generate_IRR_map_old():
    #2D storage of IRR because it does not have analytical form
    
    number_of_payments_array = np.arange(0,30*12) #30years
    IRR_array = np.linspace(-10,40, num=100)

    store_array = np.zeros((len(number_of_payments_array),len(IRR_array)))
    for ni, N in enumerate(number_of_payments_array):
        for ai, IRR in enumerate(IRR_array):
            r = IRR/12/100
            SolarT_value_over_m0 = ((1+r)**N - 1)/(r * (1+r)**N)
            store_array[ni,ai] = SolarT_value_over_m0
            
    #https://jakevdp.github.io/PythonDataScienceHandbook/04.12-three-dimensional-plotting.html
    X, Y = np.meshgrid(IRR_array, number_of_payments_array)
    Z = store_array
    
    plt.figure(figsize=(15,12))
    ax = plt.axes(projection='3d')
    ax.xaxis.labelpad=15
    ax.yaxis.labelpad=25
    ax.zaxis.labelpad=15
    #ax.plot_wireframe(X, Y, Z, color = 'black')
    ax.plot_surface(np.log10(Z), Y, X, rstride=1, cstride=1, cmap='inferno', edgecolor='none')
    #ax.plot_surface(X0, Y0, np.zeros(X0.shape), rstride=1, cstride=1, color='grey', edgecolor='none', alpha = 0.2)
    ax.plot(np.log10(Z[:,0]),Y[:,0], -10, color = 'blue', lw=5)
    ax.plot(np.log10(Z[:,-1]),Y[:,-1], 40, color = 'black', lw=5)
    #ax.fill_between(np.log10(Z[:,-1]),1e4,Y[:,-1], color = 'black', alpha=0.2)
    #ax.fill_between(np.log10(Z[:,0]),Y[:,0], color = 'black', alpha=0.2)
    ax.set_zlabel('Annual IRR[%]')
    ax.set_ylabel('Number of payments')
    ax.set_xlabel('Panel price / monthly payment')
    plt.xticks([0,1,2,3],['$10^0$','$10^1$','$10^2$','$10^3$'])
    #ax.set_xscale('log')
    plt.show()
            


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
        val = estimate_SolarT_value(monthly_payment, n, anual_IRR_book)
        SolarT_value.append(val)
        generated_profits.append((number_of_payments-n)*monthly_payment)
        
    SolarT_value = np.array(SolarT_value)
    generated_profits = np.array(generated_profits)
    portfolio_value = SolarT_value + generated_profits
    
    plt.figure(figsize=(10,5))
    plt.title('Portfolio Graph graph for a panel with %sUSD monthly payments and a %s%% IRR' % (monthly_payment, anual_IRR_book), fontsize = 17)
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




