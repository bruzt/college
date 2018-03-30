#!/usr/bin/env python3

from threading import Thread, Semaphore, Barrier
from time import sleep
from random import randint as rand
 
 # Each philosopher is a thread
class Philosopher(Thread):         
    def __init__(self, phil):   
        super().__init__()  
         
        self.nPhil = phil       # Number of the philosopher
        self.hunger = 0
                 
    def run(self):          
            b.wait()        # Barrier waits until all philosophers are ready
            sleep(0.5)
            while True:  
                while True:
                    print("\nPhilosopher " + str(self.nPhil) + " is hungry (" + str(self.hunger) + ")...")
     
                    # take left fork
                    fork[self.nPhil].acquire() 
     
                    # try to take right fork
                    if fork[(self.nPhil + 1) % numPhil].acquire(timeout=5) == True: 
                        # Start eating
                        print("\n\t\t\t\tPhilosopher {i} is eating...".format(i=self.nPhil)) 
                        sleep(rand(3, 6))            
     
                    else:
                        # Give up eating for a few seconds.
                        fork[self.nPhil].release() 
                        fork[(self.nPhil + 1) % numPhil].release()
                        self.hunger += 1         
                        sleep(rand(1, 3))
                        break    # restart 
                    
                    # Drop the forks after eating
                    fork[self.nPhil].release()                
                    fork[(self.nPhil + 1) % numPhil].release()

                    self.hunger = 0 
                    
                    # Start thinking
                    print("\n\t\t\t\t\t\t\t\tPhilosopher %i is thinking..." % self.nPhil)
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
 
    # Start the threads
    for i in range(numPhil): 
        print("Philosopher ", i)
        Philosopher(i).start()
 
    while True:
        sleep(1000)
