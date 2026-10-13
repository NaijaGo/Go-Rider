# Rider partnership agreement and daily bonus

## Authorized temporary pause

Go-Rider 1.0.5+12 understands a server-confirmed temporary agreement pause. This
does not set acceptance to true, create consent records or grant rider approval.
Login/session restoration, online checks, order loading and notification routing
use the verified access status. Pending/limited sessions still go to pending approval;
restricted accounts remain blocked. Network failures clear the verified pause and
new delivery work still requires backend authorization. No pause is saved locally.

Deploy the matching backend and set `RIDER_AGREEMENT_ENFORCEMENT=false` there;
there is no Flutter flag. Older rider builds remain gated and need an update. Default
backend behavior still enforces acceptance. See the [activation, resume and rollback
instructions](https://github.com/NaijaGo/naijago_backend/blob/main/docs/rider-agreement-temporary-pause.md).
Database setup and document publication remain separate explicitly approved actions.
These changes have not been production deployed or verified on a live rider account.

The complete implementation inventory, API contracts, database setup and rollback instructions, test results and staging verification checklist are in:

[Backend partnership implementation report](https://github.com/NaijaGo/naijago_backend/blob/main/docs/rider-partnership-local-review.md)

The agreement screen uses the complete backend-published document. No legal text is bundled or invented. Publication and production verification remain outstanding. The daily bonus is NGN 10,000 for 20 paid completed orders on one Lagos calendar day, with admin approval before credit. GitHub publication was authorized in the subsequent CI/push task; production deployment and database changes remain outstanding. See [Codemagic release instructions](CODEMAGIC_RELEASE.md).
