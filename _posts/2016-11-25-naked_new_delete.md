---
layout: post
title:  "Çıplak new/delete kullanımından kaçının"
tags: c++ resource-management
published: true
author: fatih
---

Dinamik memory (yada genel olarak dinamik kaynaklar), genellikle masraflı olduğu ve bir şekilde lifetime sorunları çıkardığı için olabidiğince kaçınmaya çalıştığımız bir özellik. Fakat tabi ki tamamen dinamik memory kullanımından kaçınmak mümkün değil, runtime'da belli olan array sayıları, linked list kullanımı, polimorfik nesneler vs tamamen dinamik memory allocation'a bağımlı çalışan zımbırtılar.

Ancak, kaçınamıyor olmamız, dinamik kaynak yönetimi sorunlarına kafa atmak zorunda olduğumuz anlamına gelmiyor. 

## Dinamik kaynak yönetimi

Eğer ki dinamik memory ile ilgili sıkıntılarla ilgili benimle fikir birliğinde değilseniz, endişelerden bir kaçını aşağıda sıralayayım:

1. Önemli sıkıntılardan biri performans endişesi: stack'te bir obje oluşturmak _t_ zaman alıyorsa, aynı objeyi dinamik memory'de oluşturmak her zaman _t_ süreden fazla alacaktır. Dolayısıyla, bir şeyleri otomatik yada statik storage'da tutmaya çabalamak en mantıklısı.

2. Bir diğer ölümcül bir sorun ise, dinamik olarak oluşturduğunuz objeleri silmemek. Aldığınız objeleri silmeyerek birincisi, bu objenin üzerinde durduğu hafızayı sistemden alıkoyuyorsunuz, yani bildiğiniz memory leak. İkincisi, bu objenin dinamik olarak aldığı ek memory (örneğin `std::vector`) veya diğer kaynaklar olabilir, ve bu objenin destructor'ını çağırmadığınız için, diğer bu nesne ve kaynakların da gereksiz yere hayatta kalmasına sebep oluyorsunuz.

Örneğin:

```cpp
class some_class
{
  std::vector<some_class> children;
  std::ofstream log;
  
  some_class() : log("log.txt")
  {
    children.resize(8);
  }
};

some_class* ptr = new some_class;
// ... ptr'yi kullan
```

Yukarıdakı blokta, `new` ile aldığımız `*ptr` objesinin destructor'ı asla çağırılmayacak. Dolayısıyla, içinde tuttuğu `std::vector` ve `std::ofstream` objelerinin de destructor'ı da asla çağırılmayacak. `std::vector` içinde bulunan diğer `some_class` objelerine değinmeme sanırım gerek yok.

Yani, `new` ile aldığınız bir objeyi `delete` ile geri vermenizin sebebi sadece dinamik memory'yi iade etmek değil, aynı zamanda o alanda bulunan objelerin destructorlarını çağırmaktır. Tabii bir şeyleri `new` ile almazsanız, `delete`'lemek zorunda da kalmazsınız. Dolayısıyla, nesnelerinizi olabildiğince stackte oluşturmaya çabalamalısınız.

## Pointerları saralım

Bütün dinamik allocation'lardan kaçınmak çok gerçekçi bir hedef değil. Girişte saydığımız gibi sebeplerden dolayı, bir şekilde dinamik memory kullanmak zorundayız.

Öncelikle basit bir konsept ile başlayalım: destructorlar. C++'da, herhangi bir scope(fonksyon gövdesi, objeler, loop gövdesi vs) ömrünü doldurduğu zaman, o scope'a ait bütün nesnelerin destructor'ları çağırılır. Örneğin, aşağıdakı bloğu göz önünde bulundurun:

```cpp

int foo()
{
  std::vector<int> vec(128);
  int* ptr = new int[128];
  // ... vec ve ptr'yi kullan ...
} <- bu kapanış

```

Yukarıda işaretli olan kapanış, `foo` fonksyonundaki bütün local değişkenlerin destructorlarının çağırılmasına sebep olacak. `vec` nesnesinin destructor'ı, dinamik olarak alınmış memory'nin salınmasını sağlayarak herhangi bir kaynak leakinin önüne geçiyor.

Bu noktada, aslında `ptr` nesnesinin de destructor'ı çağırılmakta. Fakat, C++'a göre, pointer tiplerinin destructorları hiç bir iş yapmamakta, dolayısıyla bu destructor'ın çağırılıyor yada çağırılmıyor olması çok bir anlam ifade etmemekte. Destructorları hiç bir iş yapmadığı için, bu noktadan itibaren bu tarz pointerlara _mal_ pointer adını vereceğiz.

Peki, mal olmayan bir pointer'a nasıl sahip oluyoruz? Yapabileceğimiz en basit şey, dinamik memory'de bir nesneyi gösteren pointerları bir obje içine sarmak, ve bu objenin scope'dan düşerken, içinde tuttuğu pointerın gösterdiği objeyi de silmesini sağlamak:

```cpp
class zeki
{
  int* ptr;
public:
  zeki(int* ptr) : ptr(ptr) {}
  int* get() { return ptr; }
  ~zeki() { delete ptr; } 
}

void foo()
{
  zeki ptr(new int);
  *ptr.get() = 5;
  ... ptr.get()'i kullan ...
  // <- delete yok!
} <- *ptr.ptr bu noktada otomatik olarak siliniyor
```

7-8 satırlık bu zeki sınıfı bizi dinamik olarak aldığımız nesneleri silmeyi unutmama zahmetinden kurtarıyor. Fakat, 7-8 satırlık bir sınıf olduğu için hala yeterince zeki değil. Örneğin, bir zeki nesnesini kopyalarsak ne olur?

## Daha akıllı pointerlar

Yukarıdaki gibi bir kodu ilk defa görüyorsanız şaşırmış olabilirsiniz fakat bu tarz nesneler C++'ın kaynak yönetim mantığını oluşturuyor. Örneğin `vector`, `fstream`, `list` ve daha nice standart kütüphane sınıfı, bir çeşit kaynağı yönetmek için varlar.

C++11 ile beraber gelen çok basit ve kullanışlı bir akıllı pointer var: `std::unique_ptr`. Tıpkı yukarıdaki zeki objemiz gibi, bir pointer'ın sahipliğini üstlenip, scope'dan düşerken, gösterdiği nesneyi de yanında götüren süper nesneler. Örneğin:

```cpp
void foo()
{
  std::unique_ptr<int> ptr(new int);
  ... ptr.get()'i kullan ...
} <- bu noktada, allocate ettigimiz nesne otomatik olarak siliniyor
```

Aynı işlevi sağlamanın yanında, aynı zamanda bizim pointerın aksine kopyalanmama işlevine de sahipler. Dolayısıyla, programınızda aynı dinamik nesneyi gösteren sadece bir `unique_ptr` nesnesi olduğunu garantileyebiliyorsunuz:

```cpp
std::unique_ptr<int> ptr(new int);
std::unique_ptr<int> p2 = ptr; // illegal, unique_ptr nesneleri kopyalanamaz
```

Eğer kopyalanamayan tipler size yabancı geliyorsa, şöyle düşünün: bir unique_ptr nesnesinin kopyalanması tam olarak ne ifade etmeli? Nesnenin içinde tuttuğu pointer'ı diğerine kopyalayamayacağımız çok açık zira bu durumda aynı nesneyi gösteren 2 adet `unique_ptr` nesnesine sahip oluyoruz ve double free gibi daha da saçma sorunlara sahip oluyoruz. Bir başka fikir, vector gibi, kopyalandığında gösterdiği dinamik nesneden bir kopya oluşturup, yeni unique_ptr objesinin o nesneyi göstermesini sağlamak olabilir. Ancak, istediğiniz davranış buysa, aradığınız akıllı pointer `unique_ptr` değil.

## new

`unique_ptr` kullanarak, çıplak `delete` çağrılarından kurtulmuş olduk. Bu noktadaki nokta, delete hala çağırılıyor; fakat çağıran biz değil, `unique_ptr` objeleri. Ancak hala çıplak `new` çağrıları yapıyoruz. 

Evet, `delete`'lerden kurtulmak için son derece geçerli bir unutabilme problemimiz vardı. Fakat, new ile ilgili sorunun tam olarak nerde olduğunu göremiyor olabilirsiniz.

Temel sorun, `new` çağrılarının mal pointerlar dönüyor olması. Her ne kadar doğrudan bir `unique_ptr` ile sarıyor olsanız da, tıpkı `delete`'ler gibi bunu yapmayı unutabilirsiniz. Yada şunu yapabilirsiniz:

```cpp
int* p = new int(5);
std::unique_ptr<int> ptr(p); // tehlike
```

Her ne kadar `new` ile aldığınız nesneyi bir `unique_ptr` ile sarmış olsanız da, hala bu nesneye bir mal pointer tutuyorsunuz. Ya `unique_ptr` ile sardığınızı unutup manuel olarak bi daha silerseniz? Ya scope dışına kopyalarsanız? Ya bir başka `unique_ptr` ile daha sararsanız? Evet 3 satırlık bir blokta bu hataları yapmayacağınız kesin, fakat 500 satırlık devasa bir fonksyon içerisine, 3-4 ay sonra döndüğünüzde "aa bu pointerı niye silmiyoruz" deme ihtimaliniz gerçekten var.

"Yav bi saattir `std::unique_ptr<int> ptr(new int(5));` yapıyoruz o nerden çıktı?" diyor olabilir ve kendinizi güvende hissedebilirsiniz. Fakat bu durumla ilgili yine bir sorun bulunuyor:

```cpp
void bar(std::unique_ptr<int> p1, std::unique_ptr<float> f);
...
bar(std::unique_ptr<int>(new int(5)), 
    std::unique_ptr<float>(new float(3.14)));
...
```

`bar` fonksyonunu çağırırken, dinamik olarak iki nesne oluşturuyoruz ve ikisini de doğrudan `unique_ptr` ile sarıyoruz: süperiz. Fakat, C++ fonksyon argümanlarının çalıştırılma sırasını garantilemiyor. O ne demek derseniz, yukarıdaki `bar` fonksyonunun çağırılmasında 4 adet alt adım var:

1. `tmp1 = new int(5)`
2. `tmp2 = std::unique_ptr<int>(tmp1)`
3. `tmp3 = new float(3.14)`
4. `tmp4 = std::unique_ptr<float>(tmp3)`

C++'da argümanların evaluate edilme sırasının belirsiz olması, derleyicinizin bu adımları (1, 2, 3, 4) sırasında yapabileceği gibi (1, 3, 2, 4) veya uygun diğer herhangi bir sırada da yapabilir. Diyelim ki, 1. adımı yaptık ve 2. adımı atlayarak 3. adımı yapmaya karar verdik. C++'da new çağrıları eğer yeterince memory yoksa bir çeşit exception atmakta ve 3. adımdaki allocation gayet de başarısız olabilmekte. Tabi ki exception durumunda C++, o ana kadar oluştulmuş scope'daki bütün nesnelerin destructorlarını çağıracak. Ancak, 2. adımı sonraya bıraktığımız için, ilk `unique_ptr`'ın destructoru çağırılmayacak dolayısıyla 1. adımda aldığımız memory leak edilecek.

Dolayısıyla, new ile aldığınız pointerları doğrudan bir `unique_ptr` ile sarsanız dahi, başarısız olabilirsiniz. Bu sebeple, çıplak `new` çağrılarından kaçınmanızda ısrarcıyım.

Peki bunlardan nasıl kurtulacağız? Bu konuda çözüm yine bir C++11 kütüphane güncellemesiyle geliyor: `std::make_unique`.

```cpp
std::unique_ptr<int> ptr = std::make_unique<int>(5);
auto ptr = std::make_unique<int>(5); // daha da iyi
```

`std::make_unique`, sizin için dinamik olarak bir nesne oluşturup, size bu nesneyi gösteren bir unique_ptr dönüyor. Dolayısıyla, elinize dinamik nesneyi gösteren bir mal pointer asla geçmiyor. Bu demektir ki, bu nesneyi yanlışlıkla 2 kere silemezsiniz, bu nesneye 2 adet `unique_ptr` tutamazsınız ve fonksyon argüman evaluation sırası dolayısıyla kaynak leak edemezsiniz!

## Sonuç

Her ne kadar işinizi rahatlatsa da, unique_ptr kullanarak hala bindiğiniz dalı kesmeniz mümkün. Örnek bir kod:

```cpp
auto ptr = std::make_unique<std::string>("hello world");
...
std::string* s_ptr = ptr.get(); // tehlike
...
```

Üstteki tehlikeli satırda, yine dinamik bir nesneyi gösteren mal bir pointer elde etmeyi başardık, ve bu pointer'ı yine elle silebiliriz yada bu pointer'ı bir başka unique_ptr içine sarabiliriz. Bu noktada sıkıntı, mal pointerların hala sahiplik belirttiğini düşünmemiz. Yani default olarak basit pointerların sahiplik belirtmediğine kendinizi ikna ederseniz bu tarz sorunların hiç biriyle karşılaşmayacaksınız.

Bu yazıdan aklınızda kalması gerekenler:

+ Çıplak `new`/`delete` çağrılarından kaçının
+ Mal pointerların sahiplik belirtmesine asla izin vermeyin
+ Dinamik kaynakları her zaman bir stack nesnesinin yönetmesini sağlayın

[Konuyla alakalı CoreGuidelines bölümü](http://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#a-namerr-newdeletear11-avoid-calling-new-and-delete-explicitly)