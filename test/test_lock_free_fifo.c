#include <stdlib.h>
#include <math.h>
#include "tinycthread.h"
#include "testmacros.h"
#include "test_lock_free_fifo.h"

#include "lock_free_fifo.h"

static const int loopCount = 10000;

static int entryPointProducer(void* data)
{
    drLockFreeFIFO* f = (drLockFreeFIFO*)data;
    
    for (int i = 0; i < loopCount; i++)
    {
        int success = drLockFreeFIFO_push(f, &i);
        //printf("pushed %d (success %d)\n", i, success);
    }
    
    return 0;
}

static int entryPointConsumer(void* data)
{
    
    drLockFreeFIFO* f = (drLockFreeFIFO*)data;
    
    for (int i = 0; i < loopCount; i++)
    {
        int val = 0;
        int success = drLockFreeFIFO_pop(f, &val);
        //printf("popped %d (success %d)\n", val, success);
        
    }
    
    return 0;
    
}

static void testTwoThreads()
{
    start_test("Lock free FIFO - producer/consumer threads");
    
    //TODO: actually check stuff
    const int es = sizeof(int);
    const int c = 100;
    
    drLockFreeFIFO f;
    drLockFreeFIFO_init(&f, c, es);
    
    thrd_t t1, t2;
    thrd_create(&t1, entryPointConsumer, &f);
    thrd_create(&t2, entryPointProducer, &f);
    
    int joinRes1, joinRes2;
    thrd_join(t1, &joinRes1);
    thrd_join(t2, &joinRes2);
}

static void testSize()
{
    start_test("Lock free FIFO - size");
    
    const int es = sizeof(int);
    const int c = 100;
    
    const int nCases = 5;
    int nPush[nCases] = {10, 20, 30, 5, 90};
    int nPop[nCases] = {5, 1, 60, 10, 90};
    
    for (int i = 0; i < nCases; i++)
    {
        drLockFreeFIFO f;
        drLockFreeFIFO_init(&f, c, es);
        
        for (int j = 0; j < nPush[i]; j++)
        {
            int success = drLockFreeFIFO_push(&f, &j);
        }
        
        for (int j = 0; j < nPop[i]; j++)
        {
            int val = 0;
            int success = drLockFreeFIFO_pop(&f, &val);
        }
        
        const int expectedSize = fmaxf(0.0f, nPush[i] - nPop[i]);
        const int size = drLockFreeFIFO_getNumElements(&f);
        fail_unless(expectedSize == size, "FIFO size should be the same after pushing and popping the same number of items");
        
        drLockFreeFIFO_deinit(&f);
    }
    
    
}

void testPushUntilFull()
{
    start_test("Lock free FIFO - push until full");
    
    const int es = sizeof(int);
    const int c = 100;
    
    drLockFreeFIFO f;
    drLockFreeFIFO_init(&f, c, es);
    
    for (int i = 0; i < c; i++)
    {
        int success = drLockFreeFIFO_push(&f, &i);
        if (!success)
        {
            fail_unless(success == 1, "push to FIFO with free slots should succeed");
        }
    }
    
    int success = drLockFreeFIFO_push(&f, &c);
    fail_unless(success == 0, "push to full FIFO should fail");
    
    const int full = drLockFreeFIFO_isFull(&f);
    fail_unless(full == 1, "full FIFO should report that it's full");
    
    const int empty = drLockFreeFIFO_isEmpty(&f);
    fail_unless(empty == 0, "full FIFO should not report that it's empty");
}

static void testPushUntilFullAndPopUntilEmpty()
{
    start_test("Lock free FIFO - push until full and pop until empty");
    
    const int es = sizeof(int);
    const int c = 100;
    
    drLockFreeFIFO f;
    drLockFreeFIFO_init(&f, c, es);
    
    for (int i = 0; i < c; i++)
    {
        int success = drLockFreeFIFO_push(&f, &i);
        if (!success)
        {
            fail_unless(success == 1, "push to FIFO with free slots should succeed");
        }
    }
    
    int success = drLockFreeFIFO_push(&f, &c);
    fail_unless(success == 0, "push to full FIFO should fail");
    
    int full = drLockFreeFIFO_isFull(&f);
    fail_unless(full == 1, "full FIFO should report that it's full");
    
    int empty = drLockFreeFIFO_isEmpty(&f);
    fail_unless(empty == 0, "full FIFO should not report that it's empty");
    
    for (int i = 0; i < c; i++)
    {
        int val = 0;
        int success = drLockFreeFIFO_pop(&f, &val);
        if (success != 1)
        {
            fail_unless(success == 1, "popping from FIFO with one or more elements should succeed");
        }
        if (val != i)
        {
            fail_unless(val == i, "popped element should have the expected value");
        }
    }
    
    full = drLockFreeFIFO_isFull(&f);
    fail_unless(full == 0, "empty FIFO should not report that it's full");
    
    empty = drLockFreeFIFO_isEmpty(&f);
    fail_unless(empty == 1, "empty FIFO should report that it's empty");
}

void testLockFreeFIFO()
{
    testTwoThreads();
    testSize();
    testPushUntilFull();
    testPushUntilFullAndPopUntilEmpty();
    
}