#!/usr/bin/env python3

from threading import Thread, Semaphore, Barrier
from time import sleep
from random import randint as rand
 
class Philosopher(Thread):         
 
    def __init__(self, phil):   
        super().__init__()  
         
        self.f = phil       
        self.hunger = 0
                 
    def run(self):          
            b.wait()        
            sleep(0.5)
            while True:  
                while True:
                    print("\nPhilosopher " + str(self.f) + " is hungry (" + str(self.hunger) + ")...")
     
                    # left fork
                    fork[self.f].acquire() 
     
                    # right fork
                    if fork[(self.f + 1) % numPhil].acquire(timeout=5) == True: 
                        # Start eating
                        print("\n\t\t\t\tPhilosopher {i} is eating...".format(i=self.f)) 
                        sleep(rand(3, 6))            
     
                    else:
                        # Give up eating for a few seconds.
                        fork[self.f].release() 
                        fork[(self.f + 1) % numPhil].release()
                        self.hunger += 1         
                        sleep(rand(1, 3))
                        break
                    
                    # Drop the forks after eating
                    fork[self.f].release()                
                    fork[(self.f + 1) % numPhil].release()

                    self.hunger = 0 
                    
                    # Start thinking
                    print("\n\t\t\t\t\t\t\t\tPhilosopher %i is thinking..." % self.f)
                    sleep(rand(4, 8))      
     
     
 
if __name__ == "__main__":  # MAIN
    while True:
        try:
            numPhil= int(input("Table for: "))
            if numPhil <= 1:
                print("\nAt least 2 Philosophers are required")
            else:
                break
        except:
            pass

    b = Barrier(numPhil)

    fork = []
    for i in range(numPhil):
        fork.append(Semaphore()) # The forks are Semaphore Objects
 
    for i in range(numPhil): 
        print("Philosopher ", i)
        Philosopher(i).start()
 
    while True:
        sleep(1000)
