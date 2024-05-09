# Implementarea CUDA a algoritmului de consens Proof of Work din cadrul Bitcoin

## Descriere

Acest proiect reprezinta găsirea unei nonce care, atunci când se aplică o funcție hash, cum ar fi SHA-256, hash-ul va începe cu un număr de zero biți. Munca medie necesară este exponențială în funcție de numărul de biți zero necesari și poate fi verificată prin executarea unui singur hash.

## Implementare

Implementarea este realizată în limbajul de programare C++ și folosește biblioteca CUDA pentru a rula pe GPU. 

### Main

În fișierul `main.cu` se realizează citirea datelor de intrare, apelarea funcției de căutare a nonce-ului și afișarea rezultatului.

Aici ca implementare am alocat memorie pe device pentru datele de intrare și rezultat care vor fi folosite în kernel-ul de căutare a nonce-ului.

De asemenea aici am eliberat și memoria alocată pe device după ce am terminat de folosit datele.

### Kernel

Pentru funcția funcția de căutare a nonce-ului (findNonce), am folosit 256 de blocuri și 512 fire de execuție pe bloc, parametrii:

- d_block_content - blocul precedent
- d_block_hash - hash-ul pe care trebuie să-l obțin
- d_nonce - nonce-ul care trebuie găsit
- d_difficulty - dificultatea
- current_length - dimensiunea blocului

de asemenea am creat și o constantă globală pentru device, care reprezintă intervalul de căutare pentru fiecare fire de execuție.
(i = start, end = start + interval)

Am copiat datele din d_block_content pe device în d_block_content_copy, pentru a nu modifica blocul între thread-uri, d_block_content fiind un pointer.

Am luat pentru fiecare thread un interval de căutare, și am verificat dacă hash-ul obținut începe cu numărul de biți zero necesari, dacă da, am setat nonce-ul și am terminat căutarea.

Căutarea se termină când un thread găsește nonce-ul și setează flagul found, care este global pentru toate thread-urile sau când toate thread-urile au terminat căutarea.

### Rezultate

Am testat pe clusterul de la facultate și am obținut următoarele rezultate:

