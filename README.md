it is a promise write by object-c

how to use it 

```
    QXPromise * x = [QXPromise promise];
    [x fulfill:@5]; // prepareData
    
    
    QXPromiseEventHandler a = ^ id (id a){
        
        NSLog(@"fuck");
        
        return @6;
    };
    
    QXPromiseEventHandler c = ^ id (id a){
        sleep(6);
        NSLog(@"fuck");
        
        return @6;
    };
    
    QXPromiseEventHandler b = ^ id (id a){
        
        NSLog(@"fuckccc");
        return a;
    };
    
    x.then(a,b).next(c).next(b);
```
