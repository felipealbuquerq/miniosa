#include <stdlib.h>
#include "atomic.h"
#include "test_atomic.h"
#include "testmacros.h"

static void testStore()
{
    start_test("Atomic store");
    
    const int r = 1000;
    srand(1234);
    for (int i = -r; i < r; i++)
    {
        int valRef = rand() % 100000;
        int val = 0;
        drAtomicStore(valRef, &val);
        if (val != valRef)
        {
            fail_unless(val == valRef, "atomically stored value should equal reference value");
        }
    }
}

static void testLoad()
{
    start_test("Atomic load");
    
    const int r = 1000;
    srand(1234);
    for (int i = -r; i < r; i++)
    {
        int valRef = rand() % 100000;
        int val = drAtomicLoad(&valRef);
        if (val != valRef)
        {
            fail_unless(val == valRef, "atomically loaded value should equal reference value");
        }
    }
}

static void testAdd()
{
    start_test("Atomic add");
    
    const int r = 1000;
    srand(1234);
    for (int i = -r; i < r; i++)
    {
        const int valRef = rand() % 100000;
        int val = valRef;
        drAtomicAdd(&val, i);
        if ((val - i) != valRef)
        {
            fail_unless((val - i) == valRef, "atomically incremented value should equal reference value");
        }
    }
}

void testAtomic()
{
    testStore();
    testLoad();
    testAdd();
}