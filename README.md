# Films recommandés

Site privé de recommandations de films. Seules les adresses e-mail de la liste des invités peuvent entrer : chacun tape son e-mail, reçoit un lien d'entrée, et peut ajouter, modifier ou supprimer ses propres films. Un invité « admin » peut modifier ou supprimer tous les films.

- `index.html` : le site (aucune compilation nécessaire)
- `config.js` : l'adresse du projet Supabase et sa clé publique
- `supabase/schema.sql` : les tables et les règles d'accès

## Mise en ligne (une seule fois, environ 20 minutes)

### 1. Supabase (la base de données et les connexions)

1. Créer un compte sur [supabase.com](https://supabase.com) puis **New project** (région Europe, mot de passe au choix, à garder).
2. Menu **SQL Editor** > **New query** : coller tout le contenu de `supabase/schema.sql`, cliquer **Run**.
3. Ajouter les invités, toujours dans **SQL Editor** (adresses en minuscules) :
   ```sql
   insert into public.invites (email, name, is_admin) values
     ('moi@exemple.fr', 'Tutu', true),
     ('ami@exemple.fr', 'Marie', false);
   ```
4. Menu **Project Settings** > **API** : copier **Project URL** et la clé **anon public** (ou « publishable ») dans `config.js`.

### 2. Vercel (l'hébergement)

1. Créer un compte sur [vercel.com](https://vercel.com) avec « Continue with GitHub ».
2. **Add New** > **Project** > importer le dépôt `films-recommandes` > **Deploy** (aucun réglage à changer).
3. Noter l'adresse obtenue, par exemple `https://films-recommandes.vercel.app`.

### 3. Relier les deux

Dans Supabase, **Authentication** > **URL Configuration** :
- **Site URL** : l'adresse Vercel.
- **Redirect URLs** : ajouter l'adresse Vercel suivie de `/**`.

### 4. Envoi des e-mails (indispensable pour inviter d'autres personnes)

Le service d'e-mail intégré de Supabase n'envoie qu'aux membres de l'équipe Supabase, et au plus quelques e-mails par heure. Pour les invités, il faut brancher un vrai envoi d'e-mails. Avec un compte Gmail :

1. Activer la validation en deux étapes sur le compte Google, puis créer un **mot de passe d'application** sur [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords).
2. Dans Supabase, **Authentication** > **Emails** > **SMTP Settings** > activer **Custom SMTP** :
   - Sender email : l'adresse Gmail ; Sender name : `Films recommandés`
   - Host : `smtp.gmail.com` ; Port : `465`
   - Username : l'adresse Gmail ; Password : le mot de passe d'application
3. Facultatif, dans **Authentication** > **Emails** > **Templates** > **Magic Link**, mettre l'objet « Votre lien d'entrée : Films recommandés ».

## Au quotidien

- **Ajouter un invité** : SQL Editor, `insert into public.invites (email, name) values ('adresse@exemple.fr', 'Prénom');`
- **Retirer un invité** : `delete from public.invites where email = 'adresse@exemple.fr';` Il ne verra plus rien, même s'il était connecté.
- Ou bien directement dans **Table Editor** > `invites`.
