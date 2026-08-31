// Post-victory map voting for the managed RWR Unraid Invasion mode.
//
// Vanilla Invasion commits to the first unfinished stage as soon as a match
// ends. This rotator pauses that decision indefinitely, presents up to three
// unfinished maps, and waits for a majority of connected players to choose.

class RwrUnraidMapVoteRotator : MapRotatorInvasion {
	protected bool m_voteActive;
	protected float m_majorityCheckTimer;
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

		m_voteActive = true;
		announceVoteOptions();
	}

	void update(float time) {
		if (!m_voteActive) {
			return;
		}

		m_majorityCheckTimer -= time;
		if (m_majorityCheckTimer <= 0.0f) {
			m_majorityCheckTimer = 1.0f;
			int winningChoice = getMajorityChoice();
			if (winningChoice >= 0) {
				finishVote(winningChoice);
			}
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
		int choice = -1;
		if (parameters.size() == 1) {
			if (parameters[0] == "1") {
				choice = 0;
			} else if (parameters[0] == "2") {
				choice = 1;
			} else if (parameters[0] == "3") {
				choice = 2;
			}
		}

		if (choice < 0) {
			sendPrivateMessage(m_metagame, senderId, "Usage: /vote 1, /vote 2, or /vote 3");
			return;
		}

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

		int winningChoice = getMajorityChoice();
		if (winningChoice >= 0) {
			finishVote(winningChoice);
		}
	}

	protected void announceVoteOptions(int playerId = -1) {
		array<const XmlElement@> players = getPlayers(m_metagame);
		int requiredVotes = int(players.size() / 2) + 1;
		string header = "Choose the next map. Voting stays open until one option has " +
			requiredVotes + " vote(s):";
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

	protected int getMajorityChoice() {
		array<const XmlElement@> players = getPlayers(m_metagame);
		int requiredVotes = int(players.size() / 2) + 1;
		array<int> totals;
		totals.resize(m_voteStageIndices.size());

		// Only count people who are still connected. This prevents a player who
		// left during an indefinite ballot from supplying a stale deciding vote.
		for (uint i = 0; i < players.size(); ++i) {
			string playerName = players[i].getStringAttribute("name");
			int voterIndex = m_voterNames.find(playerName);
			if (voterIndex >= 0) {
				int choice = m_voterChoices[voterIndex];
				if (choice >= 0 && choice < int(totals.size())) {
					totals[choice] += 1;
				}
			}
		}

		for (uint i = 0; i < totals.size(); ++i) {
			if (totals[i] >= requiredVotes) {
				return i;
			}
		}
		return -1;
	}

	protected void finishVote(int winningChoice) {
		int winningStage = m_voteStageIndices[winningChoice];
		sendFactionMessage(m_metagame, 0,
			"Map choice confirmed: " + getMapName(winningStage) + ". Preparing extraction.");

		resetVote();
		m_nextStageIndex = winningStage;
		waitAndStart(1.0f, false);
	}

	protected void resetVote() {
		m_voteActive = false;
		m_majorityCheckTimer = 1.0f;
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
