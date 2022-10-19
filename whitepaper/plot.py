import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

#https://www.statista.com/statistics/1267500/eu-monthly-wholesale-electricity-price-country/
#https://terresolaire.com/Blog/rentabilite-photovoltaique/tarif-rachat-photovoltaique/

def main():
    electricity_df = pd.read_csv('Electricity_FR_DE.csv', header = 0, sep = '\t')
    
    FR = electricity_df['France'].to_numpy()/1000
    DE = electricity_df['Germany'].to_numpy()/1000
    
    plt.figure(figsize=(10,6))
    plt.plot(FR, label = 'France', color = 'blue')
    plt.plot(DE, label = 'Germany', color = 'green')
    plt.axhline(y=0.1, label = 'PPA < 100kWc', color = 'red')
    plt.axhline(y=0.12, label = 'PPA < 36kWc', color = 'orange')
    plt.axhline(y=0.15, label = 'PPA < 9kWc', color = 'gold')
    plt.axhline(y=0.19, label = 'PPA < 3kWc', color = 'yellow')
    plt.legend(prop={'size':12})
    plt.yscale('log')
    plt.xlabel('Month')
    plt.xticks([0,11,23], ([2020,2021,2022]))
    plt.ylabel('Electricity price [EUR/kWh]')
    plt.ylim(0.01,1)
    plt.ylim(0.01,0.5)
    plt.show()
    
    
    


if __name__ == '__main__':#
    plt.rcParams.update({'font.size': 16})
    main()