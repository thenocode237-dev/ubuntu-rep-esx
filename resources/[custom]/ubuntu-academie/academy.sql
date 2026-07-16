-- ubuntu-academie — suivi des joueurs déjà accueillis à l'académie.
-- Un joueur absent de cette table est « nouveau » : il reçoit à sa première
-- connexion une notification l'invitant à se rendre à l'académie. Il y est
-- ajouté dès qu'il ouvre le menu de l'académie (ne sera plus relancé).
CREATE TABLE IF NOT EXISTS `ubuntu_academy_seen` (
    `identifier` VARCHAR(64)  NOT NULL,
    `seen_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
