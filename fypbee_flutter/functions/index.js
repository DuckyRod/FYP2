const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

async function sendNotificationToUser(userId, title, body) {
  if (!userId) return;

  const userDoc = await admin.firestore().collection("users").doc(userId).get();

  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const token = userData.fcmToken;

  if (!token) return;

  await admin.messaging().send({
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
  });
}

exports.notifySupervisorOnProposalSubmitted = onDocumentCreated(
  "proposals/{proposalId}",
  async (event) => {
    const proposal = event.data.data();

    await sendNotificationToUser(
      proposal.supervisorId,
      "New Proposal Submitted",
      `${proposal.studentName || "A student"} submitted a proposal: ${proposal.title || "-"}`
    );
  }
);

exports.notifyStudentOnProposalStatusChange = onDocumentUpdated(
  "proposals/{proposalId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return;

    await sendNotificationToUser(
      after.studentUid || after.studentUserId || after.uid,
      "Proposal Status Updated",
      `Your proposal status is now: ${after.status}`
    );
  }
);

exports.notifySupervisorOnMeetingLogSubmitted = onDocumentCreated(
  "meeting_logs/{logId}",
  async (event) => {
    const log = event.data.data();

    await sendNotificationToUser(
      log.supervisorId,
      "New Meeting Log Submitted",
      `${log.studentName || "A student"} submitted ${log.meetingTitle || "a meeting log"}`
    );
  }
);

exports.notifyStudentOnMeetingLogStatusChange = onDocumentUpdated(
  "meeting_logs/{logId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return;

    await sendNotificationToUser(
      after.studentUid,
      "Meeting Log Updated",
      `Your meeting log status is now: ${after.status}`
    );
  }
);

exports.notifySupervisorOnFinalSubmission = onDocumentCreated(
  "final_submissions/{submissionId}",
  async (event) => {
    const submission = event.data.data();

    await sendNotificationToUser(
      submission.supervisorId,
      "New Final Submission",
      `${submission.studentName || "A student"} submitted the final project.`
    );
  }
);

exports.notifyStudentOnFinalMarkReleased = onDocumentUpdated(
  "final_submissions/{submissionId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.mark === after.mark) return;

    await sendNotificationToUser(
      after.studentUid,
      "Final Mark Released",
      `Your final mark is ${after.mark} (${after.grade || "-"})`
    );
  }
);