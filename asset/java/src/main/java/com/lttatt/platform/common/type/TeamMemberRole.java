package com.lttatt.platform.common.type;

public enum TeamMemberRole {
  Owner(3),
  Admin(2),
  Member(1);

  private final int level;

  TeamMemberRole(int level) {
    this.level = level;
  }

  public boolean includes(TeamMemberRole requiredRole) {
    return level >= requiredRole.level;
  }
}
