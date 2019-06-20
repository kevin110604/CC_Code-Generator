void main()
{
    float f = 8.9;
    int a;
    float b = 5.2;
    int fifty = 50;
    float bbbb;
    float g = 555555;
    int one = 1;
    int two = 2;
    int six = 6;
    int five = 5;

    //int nine = 9;
    //int ten = 10;
    //int selection = 4;
    

    print(f);
    //print(fifty);
    //print(a);
    a = 1 + 2 + 3.0 + fifty + 4 * 5 * (6 + 7 + 8)/2 - 3*2;
    //bbbb = a + 8.7 * 3.14159 - 101.1 * 2 * 4.0 * 3.3 * 7;
    
    print(a);
    //print(bbbb);

    //a = 1 + b * 5;
    //print(a);
    a %= 6;
    print(a);

    b = 6.2 + a++;
    print(a);
    print(b);

    //g = one++ + two++ + five-- *six++;
    print(g);
    //print(one);
    //print(two);
    //print(five);
    //print(six);
    //six++;
    //print(six);
    //1000+3-666;

    //if (a > one) {
    //    print(a);
    //    print("a is bigger than one");
    //}
    //else {
    //    print("a is not bigger than one");
        //int shitshit = 870;
    //    print(six);
    //    print(two);
    //}
    //print("out side if_else");

    int selection = 3;
    int rmd;
    print(rmd);
    rmd = selection % 2;
    print(rmd);

    if (selection == 1) {
        print(" ");
        print("1");
    }
    else if (selection == 2) {
        print(" ");
        print("2");
    }
    else if (selection == 3) {
        print(" ");
        print("3");

        if (selection <= 1) {
            print("nest if");
        }
        else {
            print("nest else");
            if (15 == 16) {
                print("nested nested if");
            }
            else
                print("nested nested else");
        }

    }
    else if (selection == 4) {
        print(" ");
        print("4");
    }
    else if (selection == 5) {
        print(" ");
        print("5");
    }
    else if (selection == 6) {
        print(" ");
        print("6");
    }
    else {
        print(" ");
        print("?");
    }

    float h = 3.14;

    print(h);

    if (h < 3.15) {
        print("yes");
        if (h < 100.1) {
            print("nested yes");
        }
    }
    else {
        print("no");
    }

    float aaa = 9.0;
    while (aaa >= 0.0){
        print(aaa);
        aaa--;
    }

    return;
}
