// Post-victory map voting for the managed RWR Unraid Invasion mode.
//
// Vanilla Invasion commits to the first unfinished stage as soon as a match
// ends. This rotator pauses that decision for 30 seconds, presents up to three
// unfinished maps, and lets connected players vote through chat.

class RwrUnraidMapVoteRotator : MapRotatorInvasion {
	protected bool m_voteActive;
	protected float m_voteTimeLeft;
	protected bool m_tenSecondWarningSent;
	protected array<int> m_voteStageIndices;
	protected array<string> m_voterNames;
	protected array<int> m_voterChoices;

	RwrUnraidMapVoteRotator(GameModeInvasion@ metagame) {
		super(metagame);
		resetVote();
	}

	protected void readyToAdvance() override {
		resetVote();

		for (int i = 0; i < getStageCount() && m_voteStageIndices.size() < 3; ++i) {
			if (!isStageCompleted(i)) {
				m_voteStageIndices.insertLast(i);
			}
		}

		if (m_voteStageIndices.size() == 0) {
			MapRotatorInvasion::readyToAdvance();
			return;
		}

		if (m_voteStageIndices.size() == 1) {
			int stageIndex = m_voteStageIndices[0];
			sendFactionMessage(m_metagame, 0, "Next map: " + getMapName(stageIndex));
			resetVote();
			commitToMapChange(stageIndex);
			return;
		}

		m_voteActive = true;
		m_voteTimeLeft = 30.0f;
		announceVoteOptions();
	}

	void update(float time) {
		if (!m_voteActive) {
			return;
		}

		m_voteTimeLeft -= time;
		if (!m_tenSecondWarningSent && m_voteTimeLeft <= 10.0f) {
			m_tenSecondWarningSent = true;
			sendFactionMessage(m_metagame, 0, "Map vote: 10 seconds remaining. Type /vote 1, /vote 2, or /vote 3.");
		}

		if (m_voteTimeLeft <= 0.0f) {
			finishVote();
		}
	}

	protected void handleChatEvent(const XmlElement@ event) override {
		string message = event.getStringAttribute("message");
		string sender = event.getStringAttribute("player_name");
		int senderId = event.getIntAttribute("player_id");
		bool privileged = m_metagame.getAdminManager().isAdmin(sender, senderId) ||
			m_metagame.getModeratorManager().isModerator(sender, senderId);

		if (m_voteActive && privileged && checkCommand(message, "warp")) {
			resetVote();
		}
		MapRotatorInvasion::handleChatEvent(event);

		if (checkCommand(message, "maps")) {
			if (m_voteActive) {
				announceVoteOptions(senderId);
			} else {
				sendPrivateMessage(m_metagame, senderId, "No map vote is active.");
			}
			return;
		}

		if (!checkCommand(message, "vote")) {
			return;
		}
		if (!m_voteActive) {
			sendPrivateMessage(m_metagame, senderId, "No map vote is active.");
			return;
		}

		array<string> parameters = parseParameters(message, "vote");
		if (parameters.size() != 1 || !isNumeric(parameters[0])) {
			sendPrivateMessage(m_metagame, senderId, "Usage: /vote 1, /vote 2, or /vote 3");
			return;
		}

		int choice = parseInt(parameters[0]) - 1;
		if (choice < 0 || choice >= int(m_voteStageIndices.size())) {
			sendPrivateMessage(m_metagame, senderId, "That map option is not available. Type /maps to see the choices.");
			return;
		}

		int voterIndex = m_voterNames.find(sender);
		if (voterIndex < 0) {
			m_voterNames.insertLast(sender);
			m_voterChoices.insertLast(choice);
		} else {
			m_voterChoices[voterIndex] = choice;
		}

		sendPrivateMessage(m_metagame, senderId,
			"Vote recorded for " + getMapName(m_voteStageIndices[choice]) + ".");
	}

	protected void announceVoteOptions(int playerId = -1) {
		string header = "Choose the next map. Vote ends in 30 seconds:";
		if (playerId >= 0) {
			sendPrivateMessage(m_metagame, playerId, header);
		} else {
			sendFactionMessage(m_metagame, 0, header);
		}

		for (uint i = 0; i < m_voteStageIndices.size(); ++i) {
			string option = "/vote " + (i + 1) + " - " + getMapName(m_voteStageIndices[i]);
			if (playerId >= 0) {
				sendPrivateMessage(m_metagame, playerId, option);
			} else {
				sendFactionMessage(m_metagame, 0, option);
			}
		}
	}

	protected void finishVote() {
		array<int> totals;
		totals.resize(m_voteStageIndices.size());
		for (uint i = 0; i < m_voterChoices.size(); ++i) {
			int choice = m_voterChoices[i];
			if (choice >= 0 && choice < int(totals.size())) {
				totals[choice] += 1;
			}
		}

		int winningChoice = 0;
		for (uint i = 1; i < totals.size(); ++i) {
			if (totals[i] > totals[winningChoice]) {
				winningChoice = i;
			}
		}

		int winningStage = m_voteStageIndices[winningChoice];
		if (m_voterChoices.size() == 0) {
			sendFactionMessage(m_metagame, 0,
				"No map votes were cast. Continuing to " + getMapName(winningStage) + ".");
		} else {
			sendFactionMessage(m_metagame, 0,
				"Map vote winner: " + getMapName(winningStage) + " with " + totals[winningChoice] + " vote(s).");
		}

		resetVote();
		m_nextStageIndex = winningStage;
		// The vote consumes the normal 30-second post-match delay, so change
		// immediately instead of adding another countdown.
		waitAndStart(0.0f, false);
	}

	protected void resetVote() {
		m_voteActive = false;
		m_voteTimeLeft = 0.0f;
		m_tenSecondWarningSent = false;
		m_voteStageIndices.resize(0);
		m_voterNames.resize(0);
		m_voterChoices.resize(0);
	}
}

class RwrUnraidMapVoteInvasion : GameModeInvasion {
	RwrUnraidMapVoteInvasion(UserSettings@ settings) {
		super(settings);
	}

	protected void setupMapRotator() override {
		@m_mapRotator = RwrUnraidMapVoteRotator(this);
		StageConfiguratorInvasion configurator(this, m_mapRotator);
	}
}

class RwrUnraidPersistentMapVoteInvasion : RwrUnraidPersistentInvasion {
	RwrUnraidPersistentMapVoteInvasion(UserSettings@ settings) {
		super(settings);
	}

	protected void setupMapRotator() override {
		@m_mapRotator = RwrUnraidMapVoteRotator(this);
		StageConfiguratorInvasion configurator(this, m_mapRotator);
	}
}
