Anton Stefan,
331CC

Tema2 ASC - Cuda
Algoritmul de cosens Proof of Work din cadrul Bitcoin


Durata implementare:
8~ ore


Detalii implementare:

Incepem prin a aloca memorie pe device pentru structura 'Result' si
pentru continutul blocului 'd_block_content', si dupa le copiem de
pe Host pe Device. Avem structurile blockDim si gridDim care sunt
folosite pentru a defini dimensiunile blocurilor de thread-uri si
grilei de blocuri cu care se lanseaza un kernel pe GPU. In
findNonce fiecare thread calculeaza un nonce potential,
construieste blocul de date combindand acest nonce cu continutul
de baza, calculeaza hash-ul si verifica daca respecta criteriul
de dificultate.
Idx e folosit pentru a calcula un index unic pentru fiecare thread
in grila de executie folosint ID-ul blocului, dimensiunea acestuia
si ID-ul threadului. Acest index reprezinta candidatul pentru nonce.
Definim un string pentru a stoca reprezentarea text a nonce-ului, dupa
convertirea in string intoarcem lungimea acestuia.
La final folosim memcpy ca sa adaugam string nonce-ul la sfarsitul
continutului de baza in buffer.
Cu apply_sha256 generam un hash pentru bufferul complet.
Folosim 'atomicMin' pentru a determina cel mai mic nonce care
indeplineste coniditia de dificultate si a-l actualiza in structura de
rezultate si 'atomicExch' pentru a seta variabila 'found' si a semnala
celorlalte threaduri ca s-a gasit un nonce valid.
Dupa ce s-a gasit findNonce, ne asiguram ca toate threadurile s-au terminat,
oprim timpul, copiem rezultatul inapoi de pe Device in Host, scriem
rezultatele cu printResult in results.csv, iar in final eliberam memoria
alocata pe GPU.


Rezultate:
--local pe wsl--
results.csv->
00000466c22e6ee57f6ec5a8122e67f82a381499a4b3069869819639bb22a2ee,515800,0.01


Viteza foarte buna arata ca utilizarea GPU-urilor pentru acest tip de calcul
este extrem de eficienta. Prezenta unui hash care incepe cu zerouri indica
ca nonceul gasit indeplineste cerinta de dificultate specificata pentru 
a crea un hash cu minim 5 zerouri in fata.