#!/bin/bash

# $1 for account
# $2 for domain
# run script ./delegate-admin.sh newadmin@imanudin.net imanudin.net

zmprov ma $1 zimbraIsDelegatedAdminAccount TRUE zimbraAdminConsoleUIComponents accountListView zimbraAdminConsoleUIComponents downloadsView zimbraAdminConsoleUIComponents DLListView zimbraAdminConsoleUIComponents aliasListView zimbraAdminConsoleUIComponents resourceListView

zmprov grr global usr $1 adminLoginCalendarResourceAs
zmprov grr global usr $1 domainAdminZimletRights
zmprov grr domain $2 usr $1 domainAdminRights
zmprov grr domain $2 usr $1 domainAdminConsoleRights
zmprov grr domain $2 usr $1 adminConsoleAliasRights
zmprov grr domain $2 usr $1 modifyAccount
zmprov grr domain $2 usr $1 countAlias
zmprov grr domain $2 usr $1 -configureAdminUI
zmprov grr domain $2 usr $1 -get.account.zimbraAdminConsoleUIComponents
zmprov grr domain $2 usr $1 -get.dl.zimbraAdminConsoleUIComponents
zmprov grr domain $2 usr $1 -set.account.zimbraIsDelegatedAdminAccount
zmprov grr domain $2 usr $1 -set.dl.zimbraIsAdminGroup

